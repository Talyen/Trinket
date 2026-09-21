from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/check-agent-invariants.sh',
    'Scripts/check-exclusivity-footguns.sh',
    'Scripts/internal/swift_policy.py',
    'Scripts/lib/rg-check.sh',
)

from pathlib import Path
import shutil
import subprocess
import tempfile
from script_test_support import ScriptRegressionTestCase, ROOT


class SwiftInvariantsTests(ScriptRegressionTestCase):
    def test_comment_rationale_preserves_suppression_and_concurrency_checks(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-agent-invariants.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env", "internal/swift_policy.py", "tool-versions.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            (root / ".tools").symlink_to(ROOT / ".tools", target_is_directory=True)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "Trinket/App").mkdir(parents=True)
            (root / "TrinketUITests").mkdir()
            (root / "Trinket/App/TrinketApp.swift").write_text("import SwiftUI\n")
            fixture = root / "Trinket/Probe.swift"
            cases = (
                ("// Preserve ordering across suspension.\n/* The callback owns its lifetime. */\nstruct Probe {}\n", None),
                ("// swiftlint:disable type_body_length\nstruct Probe {}\n", "swiftlint:disable must include"),
                ("// swiftlint:disable type_body_length - cohesive fixture\nstruct Probe {}\n", None),
                ("final class Probe: @unchecked Sendable {}\n", "needs a nearby Concurrency-Safety"),
                ("// Concurrency-Safety: immutable fields never change after initialization\n"
                 "final class Probe: @unchecked Sendable {}\n", None),
            )
            for source, failure in cases:
                with self.subTest(source=source):
                    fixture.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-agent-invariants.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)

    def test_agent_invariants_reject_unseeded_entropy_sleep_try_and_pin_release(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-agent-invariants.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env", "internal/swift_policy.py", "tool-versions.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            (root / ".tools").symlink_to(ROOT / ".tools", target_is_directory=True)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "Trinket/App").mkdir(parents=True)
            (root / "TrinketUITests").mkdir()
            engine_probe = root / "Packages/BattleEngine/Sources/BattleEngine/Probe.swift"
            sleep_probe = root / "Packages/BattleEngine/Tests/ProbeTests.swift"
            persistence_probe = root / "Packages/TrinketPersistence/Sources/TrinketPersistence/Probe.swift"
            app_main = root / "Trinket/App/TrinketApp.swift"

            def run_checker() -> subprocess.CompletedProcess[str]:
                return subprocess.run([str(root / "Scripts/check-agent-invariants.sh")],
                                        cwd=root, capture_output=True, text=True)

            clean = (
                (engine_probe, "struct Probe {}\n"),
                (sleep_probe, "import Testing\nstruct ProbeTests {}\n"),
                (persistence_probe, "struct Probe {}\n"),
                (app_main, "import SwiftUI\nstruct TrinketApp {}\n"),
            )
            cases = (
                ("unseeded Date",
                 ((engine_probe, "struct Probe { let now = Date() }\n"),), "unseeded Date()/UUID()"),
                ("allowed Date",
                 ((engine_probe, "// EntropyCheck: allow - deterministic fixture\nstruct Probe { let now = Date() }\n"),), None),
                ("unseeded random",
                 ((engine_probe, "struct Probe { let roll = Int.random(in: 1...6) }\n"),), "unseeded .random("),
                ("injected random",
                 ((engine_probe, "struct Probe { let roll = rng.random(in: 1...6, using: &generator) }\n"),), None),
                ("blocking Task.sleep",
                 ((sleep_probe, "import Testing\nstruct ProbeTests { func run() async { try? await Task.sleep(nanoseconds: 1_000) } }\n"),), "Task.sleep"),
                ("millisecond Task.sleep",
                 ((sleep_probe, "import Testing\nstruct ProbeTests { func run() async { try? await Task.sleep(.milliseconds(10)) } }\n"),), None),
                ("silent persistence try",
                 ((persistence_probe, "struct Probe { func load() { try? store.load() } }\n"),), "try? on persistence"),
                ("allowed persistence try",
                 ((persistence_probe, "// PersistenceCheck: allow - best-effort cache warm\nstruct Probe { func load() { try? store.load() } }\n"),), None),
                ("released artwork pins",
                 ((app_main, "import SwiftUI\nstruct TrinketApp { func reset() { view.releasePins() } }\n"),), "do not release launch artwork pins"),
            )
            for label, overwrites, failure in cases:
                with self.subTest(label=label):
                    for path, _ in clean:
                        path.write_text(dict(clean)[path])
                    for path, source in overwrites:
                        path.write_text(source)
                    result = run_checker()
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)


    def test_exclusivity_footguns_reject_self_inout_and_honor_allow(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("check-exclusivity-footguns.sh", "lib/rg-check.sh",
                          "format-dirs.env", "build-inputs.env"):
                target = root / "Scripts" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / "Scripts" / name, target)
            for package in (ROOT / "Packages").iterdir():
                if package.is_dir():
                    (root / "Packages" / package.name / "Sources" / package.name).mkdir(parents=True)
                    (root / "Packages" / package.name / "Tests").mkdir()
            (root / "TrinketUITests").mkdir()
            fixture = root / "Trinket/Probe.swift"
            fixture.parent.mkdir(parents=True)
            cases = (
                ("explicit self inout",
                 "struct Holder {\n  var count = 0\n  func bump() {\n    take(&self.count)\n  }\n}\n",
                 "&self.count"),
                ("allowed self inout",
                 "struct Holder {\n  var count = 0\n  func bump() {\n    // ExclusivityCheck: allow - copied to a local before the call\n    take(&self.count)\n  }\n}\n",
                 None),
                ("stored into without local",
                 "struct Runner {\n  var stored = 0\n  func run() {\n    apply(into: &stored)\n  }\n}\n",
                 "into: &stored"),
                ("into with function-local var",
                 "struct Runner {\n  func run() {\n    var stored = 0\n    apply(into: &stored)\n  }\n}\n",
                 None),
            )
            for label, source, failure in cases:
                with self.subTest(label=label):
                    fixture.write_text(source)
                    result = subprocess.run([str(root / "Scripts/check-exclusivity-footguns.sh")],
                                            cwd=root, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stdout + result.stderr)
                    if failure:
                        self.assertIn(failure, result.stderr)
