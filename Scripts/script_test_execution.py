#!/usr/bin/env python3
"""Require successful Python test execution in each selected script suite."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import unittest


class ExecutionResult(unittest.TextTestResult):
    successful_cases = 0

    def addSuccess(self, test):
        super().addSuccess(test)
        self.successful_cases += 1

    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        if err is None:
            self.successful_cases += 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite")
    args = parser.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent / "Tests"))
    suite = unittest.defaultTestLoader.loadTestsFromName(args.suite)
    result = unittest.TextTestRunner(resultclass=ExecutionResult, buffer=True).run(suite)
    if not result.wasSuccessful():
        return 1
    if result.successful_cases == 0:
        print(f"FAIL: {args.suite} executed zero successful tests (empty or all skipped)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
