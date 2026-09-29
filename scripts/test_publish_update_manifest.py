import copy
import hashlib
import struct
import unittest

from publish_update_manifest import make_manifest, version_key


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.binary = bytearray(128)
        self.binary[:2] = b'MZ'
        struct.pack_into('<I', self.binary, 0x3c, 64)
        self.binary[64:68] = b'PE\0\0'
        struct.pack_into('<H', self.binary, 68, 0x8664)
        self.release = {
            'tag_name': 'v1.8.1', 'draft': False, 'prerelease': False,
            'published_at': '2026-09-29T00:00:00Z', 'body': 'Test release',
            'assets': [{'name': 'QuantumGuard.exe', 'state': 'uploaded',
                        'browser_download_url': 'https://github.com/typchris/Quantum-Guard/releases/download/v1.8.1/QuantumGuard.exe',
                        'size': len(self.binary), 'digest': 'sha256:' + hashlib.sha256(self.binary).hexdigest()}],
        }

    def test_verified_manifest(self):
        result = make_manifest(self.release, self.binary)
        self.assertEqual(result['version'], '1.8.1')
        self.assertEqual(result['sha256'], hashlib.sha256(self.binary).hexdigest())
        self.assertEqual(result['channel'], 'stable')

    def test_reject_corruption(self):
        self.binary[-1] = 1
        with self.assertRaises(ValueError):
            make_manifest(self.release, self.binary)

    def test_reject_bad_metadata(self):
        for field, value in [('draft', True), ('published_at', None), ('tag_name', '../bad')]:
            with self.subTest(field=field):
                release = copy.deepcopy(self.release)
                release[field] = value
                with self.assertRaises(ValueError):
                    make_manifest(release, self.binary)
        for field, value in [('size', 1), ('state', 'new'), ('browser_download_url', 'https://evil.test/app.exe')]:
            with self.subTest(field=field):
                release = copy.deepcopy(self.release)
                release['assets'][0][field] = value
                with self.assertRaises(ValueError):
                    make_manifest(release, self.binary)

    def test_reject_wrong_platform(self):
        struct.pack_into('<H', self.binary, 68, 0x14c)
        with self.assertRaises(ValueError):
            make_manifest(self.release, self.binary)

    def test_version_order(self):
        self.assertGreater(version_key('1.10.0'), version_key('1.9.0'))
        self.assertGreater(version_key('1.8.1'), version_key('1.8.1-rc.2'))
        self.assertGreater(version_key('1.8.1-rc.10'), version_key('1.8.1-rc.2'))


if __name__ == '__main__':
    unittest.main()
