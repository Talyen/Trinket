"""Keep universal catalog observations distinct from measured delivery size and RAM."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import subprocess

from internal.cli import load_sibling

size = load_sibling('build_size', 'report-build-size.py')


class BuildSizeTests(unittest.TestCase):
    def test_catalog_reports_fallback_bytes_without_calling_them_resident_ram(self):
        result = size.catalog_report([
            {'AssetType': 'Image', 'Name': 'hero', 'Encoding': 'HEIF', 'SizeOnDisk': 100,
             'PixelWidth': 100, 'PixelHeight': 200},
            {'AssetType': 'Image', 'Name': 'hero', 'Encoding': 'RGB555', 'Compression': 'zip', 'SizeOnDisk': 900}])
        self.assertEqual(result['estimatedFullCatalogRGBABytes'], {'full': 80000})
        self.assertEqual(sum(item['bytes'] for item in result['groups']), 1000)
        self.assertNotIn('residentBytes', result)

    def test_thinned_export_failure_cleans_products_and_never_uploads(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            def fail(arguments, **kwargs):
                self.assertNotIn('-allowProvisioningUpdates', arguments)
                options = size.plistlib.loads((output / 'ExportOptions.plist').read_bytes())
                self.assertEqual(options['destination'], 'export')
                self.assertEqual(options['thinning'], '<thin-for-all-variants>')
                raise subprocess.CalledProcessError(1, arguments)
            with mock.patch.object(size.subprocess, 'run', side_effect=fail):
                with self.assertRaises(subprocess.CalledProcessError):
                    size.export_thinned(output / 'retained.xcarchive', output)
            self.assertEqual(list(output.glob('thinned-*')), [])
