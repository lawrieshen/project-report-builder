import json


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
