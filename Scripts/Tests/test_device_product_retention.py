"""Device products require a verified independent binary and symbol copy."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import ROOT
from internal import build_symbols as symbols
from internal import device_product_retention as devices


class DeviceProductRetentionTests(unittest.TestCase):
    def test_only_exact_retained_binary_and_all_symbols_authorize_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            products = root / 'Products'
            config = products / 'Release-iphoneos'
            app = config / 'Trinket.app'
            app.mkdir(parents=True)
            (app / 'Trinket').write_bytes(b'actual binary')
            current = config / 'Trinket.app.dSYM/Contents/Resources/DWARF/Trinket'
            current.parent.mkdir(parents=True)
            current.write_bytes(b'unique symbols')
            profile = root / 'artifacts/profiles/verified'
            copied = profile / 'symbols/0/Trinket.app.dSYM/Contents/Resources/DWARF/Trinket'
            copied.parent.mkdir(parents=True)
            copied.write_bytes(b'unique symbols')
            binary = profile / 'Binaries/Trinket'
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b'actual binary')
            item = {'path': 'Trinket', 'sha256': symbols.digest(binary), 'uuids': [['UUID', 'arm64']]}
            (profile / 'result.json').write_text(json.dumps({'status': 'passed', 'buildSymbols': {'binaries': [item]}}))
            symbol_root = profile / 'symbols'
            (symbol_root / 'symbol-manifest.json').write_text(json.dumps({'files': symbols.tree_hashes(symbol_root)}))
            with patch.object(symbols, 'artifact_root', return_value=root / 'artifacts'), \
                 patch.object(symbols, 'app_manifest', return_value={'binaries': [item]}):
                self.assertTrue(devices.verified_device_products(products))
                binary.write_bytes(b'changed')
                self.assertFalse(devices.verified_device_products(products))
                binary.write_bytes(b'actual binary')
                copied.write_bytes(b'changed symbols')
                self.assertFalse(devices.verified_device_products(products))
                copied.write_bytes(b'unique symbols')
                extra = config / 'unexpected.dylib'
                extra.write_bytes(b'unknown binary')
                self.assertFalse(devices.verified_device_products(products))


if __name__ == '__main__':
    unittest.main()
