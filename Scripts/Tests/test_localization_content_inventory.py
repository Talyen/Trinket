"""Prevent authored encounter copy from silently bypassing localization."""
from pathlib import Path
import tempfile
import unittest

from internal.localization_sources import content_sources, difficulty_sources, spire_sources


class EncounterCopyInventoryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_computed_encounter_actions_are_current_and_unsupported_shapes_fail(self):
        directory = self.root / 'Packages/TrinketContent/Sources/TrinketContent/Encounters'
        directory.mkdir(parents=True)
        keyword = self.root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift'
        keyword.parent.mkdir(parents=True)
        keyword.write_text('case burn = "Burn"')
        path = directory / 'JourneyModels.swift'
        path.write_text('''public enum StageEncounter {
    public var primaryActionTitle: String {
        switch self {
        case .battle, .randomBattle: "Battle"
        case .mysteryEvent: "Approach"
        }
    }
}
''')
        initial = content_sources(self.root)
        key = next(key for key, entry in initial.items() if entry['text'] == 'Approach')
        path.write_text(path.read_text().replace('"Approach"', '"Approach cautiously"'))
        self.assertEqual(content_sources(self.root)[key]['text'], 'Approach cautiously')
        path.write_text(path.read_text().replace('"Approach cautiously"', 'actionTitle(for: self)'))
        with self.assertRaisesRegex(ValueError, 'unsupported primaryActionTitle'):
            content_sources(self.root)

    def test_spire_copy_uses_identity_keys_and_rejects_uninventoried_declarations(self):
        directory = self.root / 'Packages/TrinketContent/Sources/TrinketContent/Encounters'
        directory.mkdir(parents=True)
        catalog = directory / 'SpireCatalog.swift'
        catalog.write_text('''static let spires: [SpireDefinition] = [
    spire(.ironVein, "Iron Vein", "Strike without ornament", .physical),
    spire(.cinderSpire, "Cinder Spire", "Heat that refuses to die", .burn),
]
''')
        first = spire_sources(self.root)
        self.assertEqual(len(first), 4)
        self.assertEqual(first['spire.ironvein.title']['text'], 'Iron Vein')
        self.assertEqual(first['spire.cinderspire.epithet']['text'], 'Heat that refuses to die')
        catalog.write_text(catalog.read_text().replace('Iron Vein', 'Revised Iron Vein'))
        revised = spire_sources(self.root)
        self.assertEqual(set(first), set(revised))
        self.assertEqual(revised['spire.ironvein.title']['text'], 'Revised Iron Vein')
        keyword = self.root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift'
        keyword.parent.mkdir(parents=True)
        keyword.write_text('case burn = "Burn"')
        inventory = content_sources(self.root)
        for key, entry in revised.items():
            self.assertEqual(inventory[key], entry)
        catalog.write_text(catalog.read_text().replace(', "Heat that refuses to die"', ''))
        with self.assertRaisesRegex(ValueError, 'unsupported Spire declaration'):
            spire_sources(self.root)

    def test_difficulty_titles_include_all_contract_and_voyage_cases(self):
        directory = self.root / 'Packages/TrinketContent/Sources/TrinketContent/Encounters'
        directory.mkdir(parents=True)
        contracts = directory / 'Contracts.swift'
        contracts.write_text('public enum ContractDifficulty: String {\n    case easy\n    case standard\n    case hard\n    public var title: String {\n        rawValue.capitalized\n    }\n}\n')
        (directory / 'Voyage.swift').write_text('public enum VoyageDifficulty: String {\n    case easy, medium, hard\n    public var title: String {\n        rawValue.capitalized\n    }\n}\n')
        entries = difficulty_sources(self.root)
        self.assertEqual(len(entries), 6)
        self.assertEqual(entries['difficulty.contract.standard.title']['text'], 'Standard')
        self.assertEqual(entries['difficulty.voyage.medium.title']['text'], 'Medium')
        keyword = self.root / 'Packages/TrinketCore/Sources/TrinketCore/Keyword.swift'
        keyword.parent.mkdir(parents=True)
        keyword.write_text('case burn = "Burn"')
        inventory = content_sources(self.root)
        for key, entry in entries.items():
            self.assertEqual(inventory[key], entry)
        contracts.write_text(contracts.read_text().replace('case easy', 'case easy = "simple"'))
        with self.assertRaisesRegex(ValueError, 'unsupported difficulty case'):
            difficulty_sources(self.root)
