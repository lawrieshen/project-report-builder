import boto3
import pytest
from botocore.stub import Stubber

from prb_ai.errors import Code, ComposeError
from prb_ai.secrets import load_api_key

ARN = 'arn:aws:secretsmanager:ap-southeast-2:543123648742:secret:test-abcdef'


def client():
    return boto3.client('secretsmanager', region_name='ap-southeast-2',
                        aws_access_key_id='test', aws_secret_access_key='test')


def test_reads_only_current_requested_secret():
    sdk = client()
    with Stubber(sdk) as stub:
        stub.add_response('get_secret_value', {'SecretString': '{"GEMINI_API_KEY":"dummy"}'},
                          {'SecretId': ARN, 'VersionStage': 'AWSCURRENT'})
        assert load_api_key(sdk, ARN) == 'dummy'
        stub.assert_no_pending_responses()


@pytest.mark.parametrize('value', ['{}', '[]', 'not-json', '{"GEMINI_API_KEY":null}',
    '{"GEMINI_API_KEY":""}', '{"GEMINI_API_KEY":" dummy "}',
    '{"GEMINI_API_KEY":"one","GEMINI_API_KEY":"two"}'])
def test_invalid_secret_fails_without_disclosing_content(value):
    sdk = client()
    with Stubber(sdk) as stub:
        stub.add_response('get_secret_value', {'SecretString': value})
        with pytest.raises(ComposeError) as error:
            load_api_key(sdk, ARN)
        assert str(error.value) == Code.UNAVAILABLE.value


def test_access_denial_is_sanitized():
    sdk = client()
    with Stubber(sdk) as stub:
        stub.add_client_error('get_secret_value', 'AccessDeniedException', 'sensitive details')
        with pytest.raises(ComposeError) as error:
            load_api_key(sdk, ARN)
        assert str(error.value) == Code.UNAVAILABLE.value
