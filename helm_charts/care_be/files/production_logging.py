import logging
from copy import deepcopy

from .production import *  # noqa: F403
from .production import LOGGING as PRODUCTION_LOGGING


def below_error(record):
    return record.levelno < logging.ERROR


LOGGING = deepcopy(PRODUCTION_LOGGING)
LOGGING.setdefault("filters", {})["below_error"] = {
    "()": "django.utils.log.CallbackFilter",
    "callback": below_error,
}
LOGGING["handlers"]["console"].update(
    {
        "stream": "ext://sys.stdout",
        "filters": ["below_error"],
    }
)
LOGGING["handlers"]["console_error"] = {
    "level": "ERROR",
    "class": "logging.StreamHandler",
    "stream": "ext://sys.stderr",
    "formatter": "verbose",
}
LOGGING["root"]["handlers"] = ["console", "console_error"]
for logger_config in LOGGING.get("loggers", {}).values():
    handlers = logger_config.get("handlers", [])
    if (
        logger_config.get("propagate", True) is False
        and "console" in handlers
        and "console_error" not in handlers
    ):
        logger_config["handlers"] = [*handlers, "console_error"]
