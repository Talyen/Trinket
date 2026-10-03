#!/usr/bin/env python3
"""Reuse only completed exact-commit standard checks with available UI products."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess


def api(endpoint: str) -> list[dict]:
    result = subprocess.run(
        ["gh", "api", "--paginate", "--slurp", endpoint],
        check=True, capture_output=True, text=True, timeout=90,
    )
    return json.loads(result.stdout)


def proof(run: dict, jobs: list[dict], artifacts: list[dict], sha: str, branch: str) -> dict[str, str] | None:
    if (run.get("head_sha") != sha or run.get("head_branch") != branch
            or run.get("event") != "push" or run.get("status") != "completed"
            or run.get("conclusion") != "success"):
        return None
    successful = {job.get("name") for job in jobs if job.get("conclusion") == "success"}
    required = {"tests / CI OK", "tests / gate / Generate and style"}
    required.update(f"tests / Unit tests ({shard})" for shard in ("Engine", "State", "Content", "Battle"))
    if "tests / Build and smoke UI" not in successful:
        required.update(("tests / Build for testing", "tests / Smoke UI"))
    if not required <= successful:
        return None
    # A skipped build/unit suite cannot prove product verification. A missing or
    # expired artifact also forces the ordinary build+smoke path, not a false pass.
    pattern = re.compile(rf"build-derived-data-{int(run['id'])}-(\d+)$")
    candidates = [artifact for artifact in artifacts
                  if not artifact.get("expired", True) and pattern.fullmatch(artifact.get("name", ""))]
    if not candidates:
        return None
    artifact = max(candidates, key=lambda item: int(pattern.fullmatch(item["name"])[1]))
    return {
        "standard": "true",
        "assets": str("tests / Asset codegen" in successful).lower(),
        "run-id": str(run["id"]),
        "build-artifact": artifact["name"],
    }


def find_proof(repository: str, sha: str, branch: str, run_id: str) -> dict[str, str]:
    fallback = {"standard": "false", "assets": "false", "run-id": "", "build-artifact": ""}
    try:
        pages = api(f"repos/{repository}/actions/workflows/ci.yml/runs?event=push&head_sha={sha}&per_page=20")
        for run in (run for page in pages for run in page.get("workflow_runs", [])):
            if str(run.get("id")) == run_id or run.get("conclusion") != "success":
                continue
            # filter=all retains successful jobs from previous attempts after a
            # failed-job rerun. Select the latest conclusion for each job name.
            pages = api(f"repos/{repository}/actions/runs/{run['id']}/jobs?filter=all&per_page=100")
            latest: dict[str, dict] = {}
            for job in (job for page in pages for job in page.get("jobs", [])):
                name = job.get("name", "")
                if int(job.get("id", 0)) > int(latest.get(name, {}).get("id", -1)):
                    latest[name] = job
            pages = api(f"repos/{repository}/actions/runs/{run['id']}/artifacts?per_page=100")
            artifacts = [item for page in pages for item in page.get("artifacts", [])]
            candidate = proof(run, list(latest.values()), artifacts, sha, branch)
            if candidate:
                return candidate
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as error:
        print(f"Cannot establish prior verification; running ordinary checks: {error}")
    return fallback


def main() -> None:
    result = find_proof(os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"],
                        os.environ["GITHUB_REF_NAME"], os.environ["GITHUB_RUN_ID"])
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write("".join(f"{key}={value}\n" for key, value in result.items()))
    if result["standard"] == "true":
        url = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{result['run-id']}"
        print(f"Reusing successful standard checks and test products: {url}")
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
            summary.write(f"### Exact-commit verification reuse\n\nStandard checks already passed [this run]({url}) for `{os.environ['GITHUB_SHA']}`.\n")
    else:
        print("No complete exact-commit proof with available products; running ordinary checks.")


if __name__ == "__main__":
    main()
