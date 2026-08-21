"""Typed model and merge policy for Xcode failure diagnostics."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from typing import Any


CLASSIFICATIONS = (
    "test-failure",
    "build-failure",
    "simulator-infrastructure",
    "configuration",
    "tooling",
    "unknown",
)
CLASSIFICATION_PRECEDENCE = (
    "test-failure",
    "build-failure",
    "configuration",
    "tooling",
    "simulator-infrastructure",
    "unknown",
)
MAX_ISSUES = 12
MAX_LINES = 60
MAX_DETAIL_LINES = 8
MAX_DETAIL_CHARS = 2400
MAX_MESSAGE_CHARS = 800
MAX_LINE_CHARS = 240
GENERIC_MESSAGES = {"Test reported Failed", "No failure details"}


def bounded_text(value: str, *, line_limit: int = MAX_DETAIL_LINES, char_limit: int = MAX_DETAIL_CHARS) -> tuple[str, bool]:
    """Return a compact preview and whether the source text was truncated."""
    lines = str(value or "").strip().splitlines()
    clipped = len(lines) > line_limit
    lines = lines[:line_limit]
    normalized: list[str] = []
    for line in lines:
        if len(line) > MAX_LINE_CHARS:
            line = f"{line[:MAX_LINE_CHARS - 1]}…"
            clipped = True
        normalized.append(line)
    preview = "\n".join(normalized)
    if len(preview) > char_limit:
        preview = f"{preview[:char_limit - 1]}…"
        clipped = True
    return preview, clipped


def identifier_aliases(*values: str) -> frozenset[str]:
    aliases: set[str] = set()
    for raw in values:
        value = raw.strip()
        if not value:
            continue
        aliases.add(value)
        if value.startswith("test://"):
            path = value.split("?", 1)[0].rstrip("/")
            components = path.split("/")
            if len(components) >= 2:
                aliases.add("/".join(components[-2:]))
    return frozenset(aliases)


@dataclass(frozen=True)
class IssueObservation:
    kind: str
    title: str
    message: str
    test: str = ""
    test_aliases: frozenset[str] = frozenset()
    file: str = ""
    line: int | None = None
    details: str = ""
    generic: bool = False

    def normalized(self) -> "IssueObservation":
        kind = self.kind if self.kind in CLASSIFICATIONS else "unknown"
        message = re.sub(r"\s+", " ", self.message.strip()) or "No failure details"
        return IssueObservation(
            kind=kind,
            title=self.title or "Xcode failure",
            message=message,
            test=self.test,
            test_aliases=self.test_aliases | identifier_aliases(self.test),
            file=self.file,
            line=self.line,
            details=self.details.strip(),
            generic=self.generic or message in GENERIC_MESSAGES,
        )


@dataclass
class DiagnosticIssue:
    kind: str
    title: str
    message: str
    test: str = ""
    test_aliases: set[str] = field(default_factory=set, repr=False)
    file: str = ""
    line: int | None = None
    details: str = ""
    attachments: list[str] = field(default_factory=list)
    generic: bool = field(default=False, repr=False)

    @classmethod
    def from_observation(cls, observation: IssueObservation) -> "DiagnosticIssue":
        item = observation.normalized()
        return cls(
            kind=item.kind,
            title=item.title,
            message=item.message,
            test=item.test,
            test_aliases=set(item.test_aliases),
            file=item.file,
            line=item.line,
            details=item.details,
            generic=item.generic,
        )

    def enrich(self, observation: IssueObservation) -> None:
        item = observation.normalized()
        self.test_aliases.update(item.test_aliases)
        if not self.test and item.test:
            self.test = item.test
        if self.generic and not item.generic:
            self.message = item.message
            self.generic = False
        if len(item.details) > len(self.details):
            self.details = item.details
        if not self.file and item.file:
            self.file = item.file
            self.line = item.line
        if self.title in {"", "Test failure"} and item.title:
            self.title = item.title
        if self.kind == "test-failure" and item.kind != "test-failure":
            self.kind = item.kind

    def to_dict(self) -> dict[str, Any]:
        identity = "\x1f".join(
            (self.kind, self.title, self.test, self.file, str(self.line or ""), self.message)
        )
        details, details_truncated = bounded_text(self.details)
        return {
            "id": hashlib.sha1(identity.encode("utf-8")).hexdigest()[:16],
            "kind": self.kind,
            "title": self.title,
            "message": self.message[:MAX_MESSAGE_CHARS],
            "file": self.file,
            "line": self.line,
            "test": self.test,
            "details": details,
            "details_truncated": details_truncated,
            "attachments": list(self.attachments),
        }


class IssueAccumulator:
    """Merge compatible source observations without conflating test assertions."""

    def __init__(self) -> None:
        self._issues: list[DiagnosticIssue] = []
        self._generic: list[IssueObservation] = []

    @staticmethod
    def _same_test(issue: DiagnosticIssue, observation: IssueObservation) -> bool:
        aliases = set(observation.test_aliases) | set(identifier_aliases(observation.test))
        return bool(issue.test_aliases & aliases) if aliases else issue.test == observation.test == ""

    @staticmethod
    def _locations_compatible(issue: DiagnosticIssue, observation: IssueObservation) -> bool:
        if not issue.file or not observation.file:
            return True
        return issue.file == observation.file and (
            issue.line is None or observation.line is None or issue.line == observation.line
        )

    def add(self, observation: IssueObservation) -> None:
        item = observation.normalized()
        if item.generic and item.test:
            self._generic.append(item)
            return
        for issue in self._issues:
            same_test_failure = (
                self._same_test(issue, item)
                and issue.message == item.message
                and self._locations_compatible(issue, item)
                and issue.kind != "build-failure"
                and item.kind != "build-failure"
            )
            same_non_test_failure = (
                not item.test
                and not issue.test
                and issue.kind == item.kind
                and issue.title == item.title
                and issue.message == item.message
                and issue.file == item.file
                and issue.line == item.line
            )
            if same_test_failure or same_non_test_failure:
                issue.enrich(item)
                return
        self._issues.append(DiagnosticIssue.from_observation(item))

    def finalize(self) -> list[DiagnosticIssue]:
        for observation in self._generic:
            candidates = [issue for issue in self._issues if self._same_test(issue, observation)]
            if len(candidates) == 1:
                candidates[0].enrich(observation)
            elif not candidates:
                self._issues.append(DiagnosticIssue.from_observation(observation))
        self._generic.clear()
        return self._issues


@dataclass
class SourceStatus:
    build_results: bool = False
    test_summary: bool = False
    tests: bool = False
    test_details: int = 0
    attachments: bool = False
    errors: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "build_results": self.build_results,
            "test_summary": self.test_summary,
            "tests": self.tests,
            "test_details": self.test_details,
            "attachments": self.attachments,
            "errors": [bounded_text(error, line_limit=4, char_limit=1000)[0] for error in self.errors],
        }


@dataclass
class DiagnosticReport:
    label: str
    result_bundle: str
    log: str
    exit_code: int
    classification: str
    issues: list[DiagnosticIssue]
    sources: SourceStatus
    generated_at: str
    raw_log_path: str = ""
    attachments: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "schema_version": 1,
            "label": self.label,
            "result_bundle": self.result_bundle,
            "log": self.log,
            "exit_code": self.exit_code,
            "classification": self.classification,
            "issues": [issue.to_dict() for issue in self.issues],
            "counts": {
                "total": len(self.issues),
                "by_classification": {
                    kind: sum(issue.kind == kind for issue in self.issues)
                    for kind in CLASSIFICATIONS
                },
            },
            "structured_sources": self.sources.to_dict(),
            "terminal": {"issue_limit": MAX_ISSUES, "line_limit": MAX_LINES},
            "generated_at": self.generated_at,
        }
        if self.raw_log_path:
            payload["raw_log_path"] = self.raw_log_path
        if self.attachments:
            payload["attachments"] = list(self.attachments)
        return payload
