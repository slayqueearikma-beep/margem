from slowapi import Limiter

from app.config import settings
from app.services.client_ip import get_client_ip

_kwargs: dict = {
    "key_func": get_client_ip,
    "default_limits": [settings.rate_limit],
}
if settings.redis_url.strip():
    _kwargs["storage_uri"] = settings.redis_url.strip()

limiter = Limiter(**_kwargs)
