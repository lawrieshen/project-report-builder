"""Keep acceptance runs offline by default and preserve charged request identities."""
import importlib.util
import json
from pathlib import Path
import sys

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/evaluate_live.py'
spec = importlib.util.spec_from_file_location('evaluate_live', SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def test_default_does_not_prompt_or_connect(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(sys, 'argv', ['evaluate_live', '--results', str(tmp_path / 'results.json')])
    def forbidden(*args, **kwargs):
        pytest.fail('Dry run must not authenticate or connect')
    monkeypatch.setattr(runner.getpass, 'getpass', forbidden)
    monkeypatch.setattr(runner.http.client, 'HTTPSConnection', forbidden)
    runner.main()
    assert 'Validated 10 synthetic requests; no network calls' in capsys.readouterr().out
    assert not (tmp_path / 'results.json').exists()


def test_retry_preserves_request_and_rejects_changed_cases(monkeypatch, tmp_path):
    results = tmp_path / 'results.json'
    monkeypatch.setattr(sys, 'argv', ['evaluate_live', '--execute', '--results', str(results)])
    monkeypatch.setattr(runner.getpass, 'getpass', lambda _: 'private-token')
    bodies = []
    class Connection:
        def __init__(self, *args, **kwargs):
            pass
        def request(self, method, path, body, headers):
            assert results.exists()
            bodies.append(body)
            raise TimeoutError('Do not disclose private-token')
        def close(self):
            pass
    monkeypatch.setattr(runner.http.client, 'HTTPSConnection', Connection)
    for _ in range(2):
        with pytest.raises(SystemExit) as error:
            runner.main()
        assert error.value.code == 1
    assert bodies[0] == bodies[1]
    assert 'private-token' not in results.read_text()
    assert json.loads(results.read_text())['cases']['en-numbers']['status'] == 'unknown'
    original_cases = runner.cases()
    original_cases[0]['notes'] += ' Changed instruction.'
    monkeypatch.setattr(runner, 'cases', lambda: original_cases)
    with pytest.raises(SystemExit, match='Cases or request fixtures changed'):
        runner.main()
    assert len(bodies) == 2
