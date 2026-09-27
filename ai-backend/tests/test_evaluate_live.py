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


def test_sign_in_uses_public_client_and_returns_only_access_token(monkeypatch, capsys):
    monkeypatch.setattr(sys.stdin, 'isatty', lambda: True)
    monkeypatch.setattr('builtins.input', lambda _: 'tester@example.com')
    monkeypatch.setattr(runner.getpass, 'getpass', lambda _: 'private-password')
    calls = []
    class Connection:
        status = 200
        def __init__(self, host, timeout):
            assert host == 'cognito-idp.ap-southeast-2.amazonaws.com'
        def request(self, method, path, body, headers):
            calls.append(json.loads(body))
        def getresponse(self):
            return self
        def read(self, size):
            return b'{"AuthenticationResult":{"AccessToken":"access-token","RefreshToken":"refresh-token"}}'
        def close(self):
            calls.append('closed')
    monkeypatch.setattr(runner.http.client, 'HTTPSConnection', Connection)
    assert runner.sign_in() == 'access-token'
    assert calls[0]['AuthFlow'] == 'USER_PASSWORD_AUTH'
    assert calls[0]['AuthParameters']['PASSWORD'] == 'private-password'
    assert calls[-1] == 'closed'
    assert capsys.readouterr().out == ''


def test_sign_in_does_not_echo_provider_errors(monkeypatch):
    monkeypatch.setattr(sys.stdin, 'isatty', lambda: True)
    monkeypatch.setattr('builtins.input', lambda _: 'tester@example.com')
    monkeypatch.setattr(runner.getpass, 'getpass', lambda _: 'private-password')
    class Connection:
        def __init__(self, *args, **kwargs):
            pass
        def request(self, *args, **kwargs):
            raise RuntimeError('private-password')
        def close(self):
            pass
    monkeypatch.setattr(runner.http.client, 'HTTPSConnection', Connection)
    with pytest.raises(SystemExit) as error:
        runner.sign_in()
    assert 'private-password' not in str(error.value)
    assert 'Sign-in failed' in str(error.value)


def test_sign_in_requires_interactive_terminal(monkeypatch):
    monkeypatch.setattr(sys.stdin, 'isatty', lambda: False)
    with pytest.raises(SystemExit, match='Interactive terminal required'):
        runner.sign_in()


def test_case_selection_keeps_full_fingerprint_and_selected_request_identity(monkeypatch, tmp_path):
    results = tmp_path / 'selected.json'
    monkeypatch.setattr(runner.getpass, 'getpass', lambda _: 'private-token')
    bodies = []
    class Connection:
        def __init__(self, *args, **kwargs):
            pass
        def request(self, method, path, body, headers):
            bodies.append(json.loads(body))
            raise TimeoutError('stop after selected case')
        def close(self):
            pass
    monkeypatch.setattr(runner.http.client, 'HTTPSConnection', Connection)
    for arguments in [[], ['--case', 'en-missing-date']]:
        monkeypatch.setattr(sys, 'argv', ['evaluate_live', '--execute', '--case', 'en-concise',
                                         '--results', str(results), *arguments])
        with pytest.raises(SystemExit) as error:
            runner.main()
        assert error.value.code == 1
    assert 'exactly two' in bodies[0]['messages'][0]['text']
    assert 'milestone' in bodies[1]['messages'][0]['text']
    assert set(json.loads(results.read_text())['cases']) == {'en-concise', 'en-missing-date'}
