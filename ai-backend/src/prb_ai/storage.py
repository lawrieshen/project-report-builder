"""Persist AI ledger changes with atomic version checks."""

from dataclasses import dataclass
from typing import Protocol
from uuid import uuid4

from botocore.exceptions import ClientError


@dataclass(frozen=True)
class Row:
    key: str
    version: int
    data: str
    expires_at: int | None = None


@dataclass(frozen=True)
class Write:
    key: str
    expected_version: int
    data: str
    expires_at: int | None = None


class UsageStore(Protocol):
    def read(self, key: str) -> Row | None: ...

    def commit(self, writes: list[Write]) -> bool:
        """Return false only for version conflicts; raise all other storage failures."""
        ...


class DynamoUsageStore:
    def __init__(self, client, table: str):
        if not table.strip():
            raise ValueError("Usage table required")
        self.client = client
        self.table = table

    def read(self, key: str) -> Row | None:
        item = self.client.get_item(TableName=self.table, Key={"pk": {"S": key}}, ConsistentRead=True).get("Item")
        if not item:
            return None
        return Row(key, int(item["version"]["N"]), item["data"]["S"],
                   int(item["expiresAt"]["N"]) if "expiresAt" in item else None)

    def commit(self, writes: list[Write]) -> bool:
        transaction = []
        for write in writes:
            item = {"pk": {"S": write.key}, "version": {"N": str(write.expected_version + 1)}, "data": {"S": write.data}}
            if write.expires_at is not None:
                item["expiresAt"] = {"N": str(write.expires_at)}
            put = {"TableName": self.table, "Item": item}
            if write.expected_version == 0:
                put["ConditionExpression"] = "attribute_not_exists(pk)"
            else:
                put["ConditionExpression"] = "#version = :expected"
                put["ExpressionAttributeNames"] = {"#version": "version"}
                put["ExpressionAttributeValues"] = {":expected": {"N": str(write.expected_version)}}
            transaction.append({"Put": put})
        try:
            self.client.transact_write_items(TransactItems=transaction, ClientRequestToken=str(uuid4()))
            return True
        except ClientError as error:
            if error.response["Error"]["Code"] != "TransactionCanceledException":
                raise
            reasons = [reason.get("Code") for reason in error.response.get("CancellationReasons", [])]
            if "ConditionalCheckFailed" in reasons and all(code in {"None", "ConditionalCheckFailed"} for code in reasons):
                return False
            raise
