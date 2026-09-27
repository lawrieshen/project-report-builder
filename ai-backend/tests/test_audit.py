import json

from prb_ai.audit import provider_failure


def test_provider_failure_does_not_log_untrusted_status(capsys):
    provider_failure('api', 'private provider response')
    output = capsys.readouterr().out
    assert 'private' not in output
    assert json.loads(output)['httpStatus'] is None


def test_generation_audit_has_usage_without_content(service, request_model, capsys):
    service.compose('private-user', request_model)
    output = capsys.readouterr().out
    rows = [json.loads(line) for line in output.splitlines()]
    generation = next(row for row in rows if row['event'] == 'ai_generation')
    assert generation['inputTokens'] == 100
    assert generation['outputTokens'] == 100
    assert generation['state'] == 'COMPLETED'
    assert generation['latencyMs'] >= 0
    assert 'private-user' not in output
    assert request_model.draft.code_name not in output
    assert all('budgetPercent' in row for row in rows if row['event'] == 'ai_budget')
