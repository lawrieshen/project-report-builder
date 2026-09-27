"""Emit operational metadata only; never accept report content or credentials."""
import json
from typing import Literal


def output_rejected(reason: str) -> None:
    """Record only a fixed rejection stage; never log invalid generated content."""
    allowed = {'candidate', 'truncated', 'finish', 'part', 'empty', 'schema', 'business', 'size'}
    print(json.dumps({'event': 'ai_output_rejected',
                      'reason': reason if reason in allowed else 'unknown'}))


def provider_failure(kind: Literal['timeout', 'api', 'sdk'], status: int | None = None,
                     reason: str = 'unknown') -> None:
    """Record a generation failure category and HTTP status without SDK error text."""
    if kind not in {'timeout', 'api', 'sdk'}:
        raise ValueError('Unsupported provider failure category')
    # SDK error payloads are external input; never serialize arbitrary status values.
    safe_status = status if type(status) is int and 400 <= status <= 599 else None
    allowed_reasons = {'unknown', 'schema_complexity', 'schema', 'credential',
                       'model', 'billing', 'thinking', 'output_limit', 'unsupported_field'}
    safe_reason = reason if reason in allowed_reasons else 'unknown'
    print(json.dumps({'event': 'ai_provider_failure', 'operation': 'generate',
                      'kind': kind, 'httpStatus': safe_status, 'reason': safe_reason}))


def budget_usage(used_micros: int, limit_micros: int) -> None:
    print(json.dumps({'event': 'ai_budget', 'budgetPercent': (used_micros * 100) // limit_micros,
                      'usedMicros': used_micros, 'limitMicros': limit_micros}))


def generation(request_id: str, model: str, state: str, charged_micros: int,
               latency_ms: int, input_tokens: int | None, output_tokens: int | None) -> None:
    print(json.dumps({'event': 'ai_generation', 'requestID': request_id, 'model': model,
                      'state': state, 'chargedMicros': charged_micros, 'latencyMs': latency_ms,
                      'inputTokens': input_tokens, 'outputTokens': output_tokens}))
