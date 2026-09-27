"""Emit operational metadata only; never accept report content or credentials."""
import json


def budget_usage(used_micros: int, limit_micros: int) -> None:
    print(json.dumps({'event': 'ai_budget', 'budgetPercent': (used_micros * 100) // limit_micros,
                      'usedMicros': used_micros, 'limitMicros': limit_micros}))


def generation(request_id: str, model: str, state: str, charged_micros: int,
               latency_ms: int, input_tokens: int | None, output_tokens: int | None) -> None:
    print(json.dumps({'event': 'ai_generation', 'requestID': request_id, 'model': model,
                      'state': state, 'chargedMicros': charged_micros, 'latencyMs': latency_ms,
                      'inputTokens': input_tokens, 'outputTokens': output_tokens}))
