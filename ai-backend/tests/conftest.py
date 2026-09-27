import json
from datetime import UTC, datetime
from pathlib import Path
from threading import Lock

import pytest

from prb_ai.budget import BudgetPolicy, UsageRepository
from prb_ai.contracts import Request, parse_json
from prb_ai.service import CompositionService, Generation, Usage
from prb_ai.storage import Row

FIXTURES = Path(__file__).resolve().parents[2] / "backend/contracts/ai-compose/v1"


class MemoryStore:
    """Exercise production ledger logic with an atomic in-memory compare-and-swap store."""
    def __init__(self):
        self.rows = {}
        self.lock = Lock()
        self.unavailable = False
        self.lose_acknowledgement = False

    def read(self, key):
        with self.lock:
            if self.unavailable:
                raise OSError("Unavailable test store")
            return self.rows.get(key)

    def commit(self, writes):
        with self.lock:
            if self.unavailable:
                raise OSError("Unavailable test store")
            for write in writes:
                current = self.rows.get(write.key)
                if (current.version if current else 0) != write.expected_version:
                    return False
            for write in writes:
                self.rows[write.key] = Row(write.key, write.expected_version + 1, write.data, write.expires_at)
            if self.lose_acknowledgement:
                self.lose_acknowledgement = False
                raise OSError("Commit succeeded but acknowledgement was lost")
            return True


class FakeProvider:
    def __init__(self):
        self.calls = 0
        self.tokens = 100
        self.usage = Usage(100, 100)
        self.error = None
        self.after_generation = lambda: None
        self.output = json.dumps(json.loads((FIXTURES / "response.json").read_text())["proposal"])

    def count_input_tokens(self, request, policy):
        return self.tokens

    def generate(self, request, policy):
        self.calls += 1
        if self.error:
            raise self.error
        self.after_generation()
        return Generation(self.output, self.usage)


@pytest.fixture
def request_model():
    return parse_json(Request, (FIXTURES / "request.json").read_bytes())


@pytest.fixture
def now():
    return datetime(2026, 9, 30, 23, 59, 50, tzinfo=UTC)


@pytest.fixture
def policy():
    # Synthetic prices, not a claim about Gemini prices.
    return BudgetPolicy(model="fake", price_version="test", input_micros_per_million=1_000_000,
                        output_micros_per_million=2_000_000, monthly_limit_micros=24_000,
                        daily_limit=2, max_input_tokens=8_000, max_output_tokens=2_000)


@pytest.fixture
def store():
    return MemoryStore()


@pytest.fixture
def ledger(store):
    return UsageRepository(store)


@pytest.fixture
def provider():
    return FakeProvider()


@pytest.fixture
def service(ledger, provider, policy, now):
    return CompositionService(ledger, provider, policy, lambda: now, enabled=True)
