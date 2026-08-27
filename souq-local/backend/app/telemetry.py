"""Optional Sentry and Prometheus metrics for production."""

from __future__ import annotations

import logging
import os
import time
from collections import defaultdict
from threading import Lock

from app.config import settings

logger = logging.getLogger("margem.telemetry")

_metrics_lock = Lock()
_request_counts: dict[str, int] = defaultdict(int)
_error_counts: dict[str, int] = defaultdict(int)
_start_time = time.time()


def configure_telemetry() -> None:
    """Enable Azure Monitor and/or Sentry when configured."""
    connection = (os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING") or "").strip()
    if connection:
        _configure_azure_monitor(connection)

    dsn = (settings.sentry_dsn or "").strip()
    if dsn:
        _configure_sentry(dsn)


def _configure_azure_monitor(connection: str) -> None:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor
    except ImportError:
        logger.warning("azure-monitor-opentelemetry not installed")
        return
    try:
        configure_azure_monitor(connection_string=connection)
        logger.info("azure_monitor_configured")
    except Exception:
        logger.exception("azure_monitor_configure_failed")


def _configure_sentry(dsn: str) -> None:
    try:
        import sentry_sdk
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
    except ImportError:
        logger.warning("sentry-sdk not installed — pip install sentry-sdk")
        return
    try:
        sentry_sdk.init(
            dsn=dsn,
            environment=settings.app_env,
            integrations=[FastApiIntegration(), SqlalchemyIntegration()],
            traces_sample_rate=0.1 if settings.app_env in {"production", "prod"} else 0.0,
            send_default_pii=False,
        )
        logger.info("sentry_configured")
    except Exception:
        logger.exception("sentry_configure_failed")


def record_request(path: str, status_code: int) -> None:
    key = f"{path}:{status_code}"
    with _metrics_lock:
        _request_counts[key] += 1
        if status_code >= 500:
            _error_counts[path] += 1


def metrics_prometheus_text() -> str:
    lines = [
        "# HELP dribex_uptime_seconds Process uptime",
        "# TYPE dribex_uptime_seconds gauge",
        f"dribex_uptime_seconds {time.time() - _start_time:.3f}",
    ]
    with _metrics_lock:
        for key, count in sorted(_request_counts.items()):
            path, status = key.rsplit(":", 1)
            lines.append(f'dribex_http_requests_total{{path="{path}",status="{status}"}} {count}')
        for path, count in sorted(_error_counts.items()):
            lines.append(f'dribex_http_errors_total{{path="{path}"}} {count}')
    return "\n".join(lines) + "\n"
