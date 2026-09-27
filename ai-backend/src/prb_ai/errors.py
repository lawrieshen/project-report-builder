"""Expose stable, content-free errors to the app."""

from enum import StrEnum


class Code(StrEnum):
    DISABLED = "AI_DISABLED"
    INVALID_INPUT = "INVALID_INPUT"
    DAILY_QUOTA = "DAILY_QUOTA"
    BUDGET_EXHAUSTED = "BUDGET_EXHAUSTED"
    PENDING = "REQUEST_PENDING"
    MISMATCH = "REQUEST_MISMATCH"
    EXPIRED = "REQUEST_EXPIRED"
    RATE_LIMITED = "PROVIDER_RATE_LIMITED"
    TIMEOUT = "PROVIDER_TIMEOUT"
    INVALID_OUTPUT = "INVALID_OUTPUT"
    UNAVAILABLE = "AI_UNAVAILABLE"


class ComposeError(Exception):
    def __init__(self, code: Code):
        super().__init__(code.value)
        self.code = code
