import boto3
import pytest
from botocore.exceptions import ClientError
from botocore.stub import ANY, Stubber

from prb_ai.storage import DynamoUsageStore, Write


def client():
    # Explicit dummy credentials avoid reading the user's profile or querying metadata.
    return boto3.client("dynamodb", region_name="ap-southeast-2", aws_access_key_id="test", aws_secret_access_key="test")


@pytest.mark.parametrize("reasons,conflict", [
    (["ConditionalCheckFailed", "None"], True), ([], False),
    (["ConditionalCheckFailed", "ProvisionedThroughputExceeded"], False),
    (["ConditionalCheckFailed", "ValidationError"], False), (["ThrottlingError"], False),
])
def test_only_known_conditional_conflicts_retry(reasons, conflict):
    sdk = client()
    with Stubber(sdk) as stub:
        details = {"CancellationReasons": [{"Code": code} for code in reasons]} if reasons else {}
        stub.add_client_error("transact_write_items", "TransactionCanceledException", modeled_fields=details)
        store = DynamoUsageStore(sdk, "usage")
        if conflict:
            assert store.commit([Write("MONTH#2026-09", 1, "{}")]) is False
        else:
            with pytest.raises(ClientError):
                store.commit([Write("MONTH#2026-09", 1, "{}")])


def test_reads_require_consistency_and_only_results_expire():
    sdk = client()
    expected = {"TransactItems": [
        {"Put": {"TableName": "usage", "Item": {"pk": {"S": "REQUEST#alice#id"}, "version": {"N": "2"}, "data": {"S": "{}"}},
                 "ConditionExpression": "#version = :expected", "ExpressionAttributeNames": {"#version": "version"},
                 "ExpressionAttributeValues": {":expected": {"N": "1"}}}},
        {"Put": {"TableName": "usage", "Item": {"pk": {"S": "RESULT#alice#id"}, "version": {"N": "1"}, "data": {"S": "{}"}, "expiresAt": {"N": "100"}},
                 "ConditionExpression": "attribute_not_exists(pk)"}},
    ], "ClientRequestToken": ANY}
    with Stubber(sdk) as stub:
        stub.add_response("transact_write_items", {}, expected)
        stub.add_response("get_item", {}, {"TableName": "usage", "Key": {"pk": {"S": "REQUEST#alice#id"}}, "ConsistentRead": True})
        store = DynamoUsageStore(sdk, "usage")
        assert store.commit([Write("REQUEST#alice#id", 1, "{}"), Write("RESULT#alice#id", 0, "{}", 100)])
        assert store.read("REQUEST#alice#id") is None
        stub.assert_no_pending_responses()
