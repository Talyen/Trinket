#!/usr/bin/env python3
"""Reuse only completed exact-commit standard checks with available UI products."""
from __future__ import annotations

import json
import argparse
import os
from pathlib import Path
import re
import subprocess

from internal.cli import load_sibling

SHARDS = load_sibling('reuse_package_scopes', 'ci-path-filter.py').SHARDS


def api(endpoint: str) -> list[dict]:
    result = subprocess.run(
        ["gh", "api", "--paginate", "--slurp", endpoint],
        check=True, capture_output=True, text=True, timeout=90,
    )
    return json.loads(result.stdout)


def matching_run(run: dict, sha: str, branch: str) -> bool:
    required = {"head_sha": sha, "head_branch": branch, "event": "push",
                "status": "completed", "conclusion": "success"}
    return all(run.get(key) == value for key, value in required.items())


def product_proof(run: dict, jobs: list[dict], artifacts: list[dict], sha: str, branch: str) -> dict[str, str] | None:
    # Transferring exact-revision products never substitutes for another gate.
    # A path-filtered, still-running, or UI-failed workflow can have a valid archive.
    qualified = run.get('event') == 'push' or (
        run.get('event') == 'workflow_dispatch' and run.get('display_title') == 'Trinket CI (verified)')
    if not qualified or run.get('head_sha') != sha or run.get('head_branch') != branch:
        return None
    builds = [job for job in jobs if job.get('name') == 'tests / Build and smoke UI']
    if len(builds) != 1:
        return None
    build = builds[0]
    if not any(
            step.get('name') == 'Restore warm cache and build' and step.get('conclusion') == 'success'
            for step in build.get('steps', [])):
        return None
    # Never take an archive from a different build attempt, even when it is newer.
    attempt = build.get('run_attempt')
    if type(attempt) is not int or attempt < 1:
        return None
    name = f'build-derived-data-{int(run["id"])}-{attempt}'
    if not any(item.get('name') == name and item.get('expired') is False for item in artifacts):
        return None
    return {'products': 'true', 'standard': 'false', 'assets': 'false',
            'run-id': str(run['id']), 'build-artifact': name}


def proof(run: dict, jobs: list[dict], artifacts: list[dict], sha: str, branch: str) -> dict[str, str] | None:
    if not matching_run(run, sha, branch):
        return None
    successful = {job.get("name"): job for job in jobs if job.get("conclusion") == "success"}
    required = {"tests / CI OK", "tests / gate / Generate and style"}
    required.update(f"tests / Unit tests ({shard})" for shard in SHARDS)
    if "tests / Build and smoke UI" not in successful:
        required.update(("tests / Build for testing", "tests / Smoke UI"))
    if not required.issubset(successful):
        return None
    for shard, packages in SHARDS.items():
        steps = successful[f"tests / Unit tests ({shard})"].get("steps", [])
        scope = f"Test packages ({' '.join(packages)})"
        if not isinstance(steps, list) or not any(
            isinstance(step, dict) and step.get("name") == scope and step.get("conclusion") == "success"
            for step in steps
        ):
            return None
    # A skipped build/unit suite cannot prove product verification. A missing or
    # expired artifact also forces the ordinary build+smoke path, not a false pass.
    pattern = re.compile(rf"build-derived-data-{int(run['id'])}-(\d+)$")
    candidates = [(int(match[1]), artifact["name"]) for artifact in artifacts
                  if artifact.get("expired") is False and (match := pattern.fullmatch(artifact.get("name", "")))]
    if not candidates:
        return None
    return {
        "standard": "true",
        "assets": str("tests / Prepared asset integrity" in successful).lower(),
        "run-id": str(run["id"]),
        "build-artifact": max(candidates)[1],
    }


def find_proof(repository: str, sha: str, branch: str, run_id: str, products_only=False) -> dict[str, str]:
    fallback = {"standard": "false", "assets": "false", "run-id": "", "build-artifact": ""}
    if products_only:
        fallback['products'] = 'false'
    try:
        event = '' if products_only else 'event=push&'
        pages = api(f"repos/{repository}/actions/workflows/ci.yml/runs?{event}head_sha={sha}&per_page=20")
        for run in (run for page in pages for run in page.get("workflow_runs", [])):
            if (str(run.get("id")) == run_id or run.get('head_sha') != sha or run.get('head_branch') != branch
                    or (not products_only and not matching_run(run, sha, branch))):
                continue
            # filter=all retains successful jobs from previous attempts after a
            # failed-job rerun. Select the latest conclusion for each job name.
            pages = api(f"repos/{repository}/actions/runs/{run['id']}/jobs?filter=all&per_page=100")
            jobs = sorted((job for page in pages for job in page.get("jobs", [])),
                          key=lambda job: int(job.get("id", 0)))
            latest = {job["name"]: job for job in jobs}
            pages = api(f"repos/{repository}/actions/runs/{run['id']}/artifacts?per_page=100")
            artifacts = [item for page in pages for item in page.get("artifacts", [])]
            checker = product_proof if products_only else proof
            candidate = checker(run, list(latest.values()), artifacts, sha, branch)
            if candidate:
                return candidate
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as error:
        print(f"Cannot establish prior verification; running ordinary checks: {error}")
    return fallback


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--products-only', action='store_true', help='Transfer products without certifying standard checks')
    args = parser.parse_args()
    # A comparison workflow may explicitly check out an older requested commit.
    source_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    result = find_proof(os.environ["GITHUB_REPOSITORY"], source_sha,
                        os.environ["GITHUB_REF_NAME"], os.environ["GITHUB_RUN_ID"], args.products_only)
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write("".join(f"{key}={value}\n" for key, value in result.items()))
    if result["standard"] == "true":
        url = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{result['run-id']}"
        print(f"Reusing successful standard checks and test products: {url}")
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
            summary.write(f"### Exact-commit verification reuse\n\nStandard checks already passed [this run]({url}) for `{source_sha}`.\n")
    elif result.get('products') == 'true':
        print(f'Using exact-commit test products from run {result["run-id"]}; all requested checks still run.')
    else:
        print("No complete exact-commit proof with available products; running ordinary checks.")


if __name__ == "__main__":
    main()
