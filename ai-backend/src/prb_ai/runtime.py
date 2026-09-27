"""Construct the enabled runtime only after authentication and request validation."""
import json
from contextlib import ExitStack
from datetime import UTC, datetime
from collections.abc import Mapping

import boto3
from botocore.config import Config
from google import genai
from google.genai import types

from .budget import BudgetPolicy, UsageRepository
from .contracts import unique_object
from .errors import Code, ComposeError
from .gemini import GeminiProvider
from .secrets import load_api_key
from .service import CompositionService
from .storage import DynamoUsageStore


def runtime_policy(environment: Mapping[str, str], now: datetime) -> BudgetPolicy:
    """Require a complete, unexpired operator-verified price schedule and approved limits."""
    try:
        expires = datetime.fromisoformat(environment['AI_PRICE_VALID_UNTIL'])
        if expires.tzinfo is None or now >= expires:
            raise ValueError('Expired price schedule')
        policy = BudgetPolicy.model_validate(json.loads(environment['AI_BUDGET_POLICY'], object_pairs_hook=unique_object))
        if policy.monthly_limit_micros > 8_000_000:
            raise ValueError('Exceeds approved application budget')
        if not policy.model.strip() or not policy.price_version.strip():
            raise ValueError('Missing model or price version')
        return policy
    except Exception:
        raise ComposeError(Code.UNAVAILABLE) from None


def build_service(environment: Mapping[str, str], resources: ExitStack) -> CompositionService:
    """Load current credentials only when enabled; release HTTP clients after the request."""
    if environment.get('AI_ENABLED', 'false') != 'true':
        raise ComposeError(Code.DISABLED)
    now = datetime.now(UTC)
    policy = runtime_policy(environment, now)
    try:
        table = environment['AI_USAGE_TABLE']
        secret = environment['GEMINI_SECRET_ARN']
        region = environment['AWS_REGION']
        if not all(value.strip() for value in (table, secret, region)):
            raise ValueError('Missing runtime configuration')
        # Bound SDK timeouts and avoid retries extending the synchronous request budget.
        config = Config(connect_timeout=1, read_timeout=2, retries={'total_max_attempts': 1})
        secrets = boto3.client('secretsmanager', region_name=region, config=config)
        resources.callback(secrets.close)
        key = load_api_key(secrets, secret)
        dynamo = boto3.client('dynamodb', region_name=region, config=config)
        resources.callback(dynamo.close)
        client = genai.Client(api_key=key, vertexai=False,
                              http_options=types.HttpOptions(retry_options=types.HttpRetryOptions(attempts=1)))
        resources.callback(client.close)
        return CompositionService(UsageRepository(DynamoUsageStore(dynamo, table)),
                                  GeminiProvider(client), policy, lambda: datetime.now(UTC), enabled=True)
    except Exception:
        raise ComposeError(Code.UNAVAILABLE) from None
