"""Single source for diagnostic output budgets."""

from pathlib import Path


def _load_limits() -> dict[str, int]:
    config = Path(__file__).with_name("config") / "diagnostic-limits.env"
    values: dict[str, int] = {}
    for line in config.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw = line.split("=", 1)
        values[key] = int(raw)
    return values


_LIMITS = _load_limits()
MAX_ISSUES = _LIMITS["TRINKET_DIAGNOSTIC_MAX_ISSUES"]
MAX_LINES = _LIMITS["TRINKET_DIAGNOSTIC_MAX_LINES"]
MAX_DETAIL_LINES = _LIMITS["TRINKET_DIAGNOSTIC_MAX_DETAIL_LINES"]
MAX_DETAIL_CHARS = _LIMITS["TRINKET_DIAGNOSTIC_MAX_DETAIL_CHARS"]
MAX_MESSAGE_CHARS = _LIMITS["TRINKET_DIAGNOSTIC_MAX_MESSAGE_CHARS"]
MAX_LINE_CHARS = _LIMITS["TRINKET_DIAGNOSTIC_MAX_LINE_CHARS"]
MAX_AGGREGATE_ISSUES = _LIMITS["TRINKET_DIAGNOSTIC_MAX_AGGREGATE_ISSUES"]
MAX_LABELS_IN_DETAIL = _LIMITS["TRINKET_DIAGNOSTIC_MAX_LABELS_IN_DETAIL"]
