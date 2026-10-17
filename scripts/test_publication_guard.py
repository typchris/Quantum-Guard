import base64
import io
import json
import tarfile
import unittest
import zipfile
from unittest.mock import patch
import publication_guard as guard


def zipped(name, data):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as archive:
        archive.writestr(name, data)
    return buf.getvalue()


class PublicationTests(unittest.TestCase):
    def test_benign_source_and_business_contact(self):
        self.assertEqual(guard.check_publication('README.md', b'Contact contact@qguard.site'), [])

    def test_private_key_inside_nested_archive(self):
        payload = b'-----BEGIN ' + b'PRIVATE KEY-----'
        result = guard.check_publication('source.zip', zipped('nested.zip', zipped('text.txt', payload)))
        self.assertTrue(any('private key' in f['reasons'] for f in result))

    def test_root_environment_file_in_archive(self):
        self.assertTrue(guard.check_publication('source.zip', zipped('.env', b'x=1')))

    def test_encoded_keystore(self):
        self.assertTrue(guard.check_publication('qa_keystore.b64', base64.b64encode(b'opaque signing bytes')))

    def test_encoded_private_key(self):
        self.assertTrue(guard.check_publication('source.b64', base64.b64encode(b'-----BEGIN ' + b'PRIVATE KEY-----')))

    def test_server_jwt_rejected_but_anon_allowed(self):
        def jwt(role):
            body = base64.urlsafe_b64encode(json.dumps({'role': role, 'padding': 'abcdefghij'}).encode()).rstrip(b'=')
            return b'eyJabcdefghijk.' + body + b'.abcdefghijklmno'
        self.assertEqual(guard.check_bytes(jwt('anon')), [])
        self.assertIn('non-anonymous account JWT', guard.check_bytes(jwt('service_role')))

    def test_utf16_binary_secret(self):
        data = ('prefix sk_' + 'live_' + 'Z'*32).encode('utf-16-le')
        self.assertTrue(guard.check_publication('application.dll', data))

    def test_export_filenames(self):
        for name in ['user_export.csv', 'sessions.json', 'database_backup.sql', 'service-account.json']:
            with self.subTest(name=name): self.assertTrue(guard.check_publication(name, b'opaque'))

    def test_gzip_archive(self):
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode='w:gz') as archive:
            member = tarfile.TarInfo('upload.jks'); member.size = 3
            archive.addfile(member, io.BytesIO(b'key'))
        self.assertTrue(guard.check_publication('source.tar.gz', buf.getvalue()))

    def test_corrupt_base64_fails_closed(self):
        self.assertTrue(guard.check_publication('source.b64', b'not valid base64!'))

    def test_nested_and_size_limits(self):
        data = zipped('file.txt', b'safe')
        self.assertTrue(guard.check_publication('deep.zip', data, depth=4))
        with patch.object(guard, 'MAX_EXPANDED_BYTES', 10):
            self.assertTrue(guard.check_publication('big.zip', data))


if __name__ == '__main__': unittest.main()
