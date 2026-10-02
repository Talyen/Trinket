"""Usage errors for agent retrieval commands include an executable help command."""

from __future__ import annotations

import argparse
import shlex
import sys


class AgentArgumentParser(argparse.ArgumentParser):
    def __init__(self, script: str, **kwargs):
        super().__init__(prog=f"Scripts/{script}", **kwargs)
        self.help_command = shlex.join(["python3", f"Scripts/{script}", "--help"])

    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        self.exit(2, f"{self.prog}: error: {message}\nTry: {self.help_command}\n")
