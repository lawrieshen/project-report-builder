"""Read only the configured Gemini secret without exposing SDK error details."""
import json

from .contracts import unique_object
from .errors import Code, ComposeError


def load_api_key(client, secret_arn: str) -> str:
    """Require a JSON SecretString containing a nonempty GEMINI_API_KEY."""
    try:
        response = client.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")
        value = json.loads(response["SecretString"], object_pairs_hook=unique_object)
        key = value["GEMINI_API_KEY"]
        if not isinstance(key, str) or not key or key != key.strip() or any(c.isspace() for c in key):
            raise ValueError("Invalid key")
        return key
    except Exception:
        raise ComposeError(Code.UNAVAILABLE) from None
