"""Publish verified metadata for the public Quantum Guard Windows release.

Runs in GitHub Actions after publishing a release. --release-json and --asset-file
allow an offline packaging check without making a GitHub request.
"""
import argparse
import hashlib
import json
import os
import re
import struct
import urllib.parse
import urllib.request
from pathlib import Path

REPOSITORY = 'typchris/Quantum-Guard'
MAX_BYTES = 256 * 1024 * 1024
VERSION = re.compile(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')


def version_key(value):
    m = VERSION.fullmatch(value.removeprefix('v'))
    if not m:
        raise ValueError('Release tag must use vMAJOR.MINOR.PATCH, optionally with a prerelease suffix')
    pre = m[4]
    identifiers = []
    for item in pre.split('.') if pre else []:
        if item.isdigit():
            if len(item) > 1 and item[0] == '0':
                raise ValueError('Invalid numeric prerelease identifier')
            identifiers.append((0, int(item)))
        else:
            identifiers.append((1, item))
    return tuple(int(m[i]) for i in (1, 2, 3)), not bool(pre), tuple(identifiers)


def validate_executable(data):
    if len(data) < 64 or len(data) > MAX_BYTES or data[:2] != b'MZ':
        raise ValueError('Asset is not a supported Windows executable')
    offset = struct.unpack_from('<I', data, 0x3C)[0]
    if offset + 24 > len(data) or data[offset:offset+4] != b'PE\0\0':
        raise ValueError('Invalid Windows executable header')
    if struct.unpack_from('<H', data, offset + 4)[0] != 0x8664:
        raise ValueError('Asset must be Windows x64')
    if struct.unpack_from('<H', data, offset + 22)[0] & 0x2000:
        raise ValueError('Asset must be an application, not a DLL')


def make_manifest(release, data):
    if release.get('draft') or not release.get('published_at'):
        raise ValueError('Publish the release before announcing it')
    tag = release['tag_name']
    version = tag.removeprefix('v')
    version_key(version)
    if '-' in version.split('+')[0] and not release['prerelease']:
        raise ValueError('Prerelease version must have the GitHub prerelease flag')
    assets = [a for a in release['assets'] if a['name'] == 'QuantumGuard.exe' and a.get('state') == 'uploaded']
    if len(assets) != 1:
        raise ValueError('Release must contain exactly one uploaded QuantumGuard.exe')
    asset = assets[0]
    expected = f'https://github.com/{REPOSITORY}/releases/download/{tag}/QuantumGuard.exe'
    if asset['browser_download_url'] != expected:
        raise ValueError('Unexpected release asset URL')
    validate_executable(data)
    if asset['size'] != len(data):
        raise ValueError('Release asset size mismatch')
    digest = hashlib.sha256(data).hexdigest()
    if asset.get('digest') and asset['digest'] != 'sha256:' + digest:
        raise ValueError('GitHub asset checksum does not match downloaded bytes')
    return {
        'version': version,
        'channel': 'prerelease' if release['prerelease'] else 'stable',
        'platform': 'windows-x64',
        'mandatory': False,
        'download_url': expected,
        'sha256': digest,
        'size': len(data),
        'release_page': f'https://github.com/{REPOSITORY}/releases/tag/{tag}',
        'notes': (release.get('body') or 'A new Quantum Guard update is available.')[:2000],
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--tag', default=os.environ.get('RELEASE_TAG'))
    p.add_argument('--release-json', type=Path)
    p.add_argument('--asset-file', type=Path)
    p.add_argument('--output', type=Path, default=Path('releases/latest.json'))
    args = p.parse_args()
    if args.release_json:
        release = json.loads(args.release_json.read_text(encoding='utf-8'))
    else:
        if not args.tag:
            p.error('A release tag is required')
        version_key(args.tag)
        endpoint = f'https://api.github.com/repos/{REPOSITORY}/releases/tags/{urllib.parse.quote(args.tag, safe="")}'
        headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'QuantumGuard-release-publisher'}
        token = os.environ.get('GITHUB_TOKEN')
        if token:
            headers['Authorization'] = 'Bearer ' + token
        with urllib.request.urlopen(urllib.request.Request(endpoint, headers=headers), timeout=30) as response:
            release = json.load(response)
    # Validate tag and source before requesting binary bytes. Never forward the API token.
    tag = release['tag_name']
    version_key(tag)
    assets = [a for a in release['assets'] if a['name'] == 'QuantumGuard.exe']
    if len(assets) != 1 or not 0 < assets[0]['size'] <= MAX_BYTES:
        raise ValueError('Attach QuantumGuard.exe before publishing the release')
    expected = f'https://github.com/{REPOSITORY}/releases/download/{tag}/QuantumGuard.exe'
    if assets[0]['browser_download_url'] != expected:
        raise ValueError('Unexpected asset URL')
    if args.asset_file:
        if args.asset_file.stat().st_size > MAX_BYTES:
            raise ValueError('Executable is too large')
        data = args.asset_file.read_bytes()
    else:
        with urllib.request.urlopen(expected, timeout=120) as response:
            data = response.read(MAX_BYTES + 1)
    manifest = make_manifest(release, data)
    outputs = [args.output]
    if manifest['channel'] == 'stable':
        outputs.append(args.output.with_name('latest-stable.json'))
    for output in outputs:
        if output.exists():
            current = json.loads(output.read_text(encoding='utf-8'))
            if version_key(current['version']) > version_key(manifest['version']):
                print(f'Skipping older release for {output.name}')
                continue
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        print(f'Prepared {output.name} for {manifest["version"]}')


if __name__ == '__main__':
    main()
