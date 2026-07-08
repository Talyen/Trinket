#!/usr/bin/env python3
"""Repair common mechanical XCTest→Swift Testing codemod mistakes."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_GLOBS = [
    "TrinketTests/**/*.swift",
    "Packages/*/Tests/**/*.swift",
]


def fix_file(path: Path) -> bool:
    text = path.read_text()
    original = text

    # guard case let .stage(_, state)) = ...
    text = re.sub(
        r"guard case let (\.\w+(?:\([^)]*\))?) =",
        lambda m: m.group(0).replace(")) =", ") =") if ")) =" in m.group(0) else m.group(0),
        text,
    )
    text = text.replace("guard case let .stage(_, state)) =", "guard case let .stage(_, state) =")

    # #expect(lhs, "msg" == nil) from botched XCTAssertNil
    text = re.sub(
        r'#expect\(([^,]+),\s*"([^"]+)"\s*==\s*nil\)',
        r'#expect(\1 == nil, "\2")',
        text,
    )

    # return Issue.record(...) in @Test bodies
    text = re.sub(
        r"(\s+)return Issue\.record\(([^)]+)\)",
        r"\1Issue.record(\2)\n\1return",
        text,
    )

    # Multiline #expect(!(expr,\n    "msg"\n))
    text = re.sub(
        r"#expect\(!\(\s*\n\s*([^,\n]+),\s*\n\s*\"([^\"]*)\"\s*\n\s*\)",
        r'#expect(!\1, "\2")',
        text,
        flags=re.MULTILINE,
    )

    # Single-line #expect(!(expr, "msg"))
    text = re.sub(
        r'#expect\(!\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*"([^"]*)"\)',
        r'#expect(!\1, "\2")',
        text,
    )

    # #expect(!(expr, file: file, line: line))
    text = re.sub(
        r"#expect\(!\(([^,()]+(?:\([^)]*\))?[^,()]*),\s*file:\s*file,\s*line:\s*line\)",
        r"#expect(!\1, file: file, line: line)",
        text,
    )

    # #expect(!(expr, "msg")) with closure arg
    text = re.sub(
        r'#expect\(!\(([^,]+,\s*"[^"]*")\)',
        lambda m: m.group(0),
        text,
    )
    text = re.sub(
        r'#expect\(!\((battle\.hasHeroEffect \{ \$0\.isControlMeter \}),\s*"([^"]*)"\)',
        r'#expect(!\1, "\2")',
        text,
    )

    # Multiline #expect(!( ... )) where inner is a function call spanning lines
    text = re.sub(
        r"#expect\(!\(\s*\n\s*(BattleConditionEvaluator\.isMet\([\s\S]*?\))\)\s*\n\s*\)",
        r"#expect(!\1)",
        text,
        flags=re.MULTILINE,
    )

    # BattleMechanicsTests: broken marked effect assertion
    text = text.replace(
        """        #expect(!(
            context.roster.activeEffects(for: enemy)).contains { if case .marked = $0.effect { return true }; return false }
        )""",
        """        #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect { return true }
                return false
            }
        )""",
    )

    # JourneyMapPresentationTests justCompletedStage block
    text = text.replace(
        """        #expect(!(
            rows.contains {
                guard case let .stage(_, state)) = $0 else { return false }
                return state == .justCompleted
            }
        )""",
        """        #expect(!rows.contains {
            guard case let .stage(_, state) = $0 else { return false }
            return state == .justCompleted
        })""",
    )

    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> int:
    changed: list[Path] = []
    for pattern in TEST_GLOBS:
        for path in sorted(ROOT.glob(pattern)):
            if fix_file(path):
                changed.append(path)

    for path in changed:
        print(f"fixed: {path.relative_to(ROOT)}")
    print(f"Updated {len(changed)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
