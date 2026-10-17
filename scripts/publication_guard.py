"""Check publication inputs without displaying matched sensitive values."""
import base64
import json
import re
import subprocess
import sys
import io
import tarfile
import zipfile
from pathlib import Path

RULES = {
    'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'provider secret': rb'(?:pdl_(?:sdbx|live)_[A-Za-z0-9_]{16,512}|sb_secret_[A-Za-z0-9_-]{16,512}|sbp_[a-f0-9]{30,128}|sk_(?:live|test)_[A-Za-z0-9]{16,512}|gh[pousr]_[A-Za-z0-9]{20,512}|github_pat_[A-Za-z0-9_]{30,512}|AKIA[A-Z0-9]{16}|GOCSPX-[A-Za-z0-9_-]{20,128})',
    'personal email': rb'@(?:gmail|hotmail|outlook|yahoo)\.[A-Za-z]{2,12}',
    'developer path': rb'[A-Za-z]:[/\\]Users[/\\][A-Za-z0-9_. -]{1,128}[/\\]',
    'literal account credential': rb'(?i)(?:access_token|refresh_token|service_role_key|api_secret|client_secret|webhook_secret|storePassword|keyPassword)\s*[=:]\s*[\x22\x27][A-Za-z0-9_./+=-]{12,512}[\x22\x27]',
}
RESTRICTED = re.compile(r'(?i)(?:^|/)(?:\.env(?:\..*)?|local\.properties|.*(?:keystore|private[_-]?key).*\.(?:b64|txt)|.*\.(?:jks|keystore|pfx|p12|key|pdb))$')
DATA_EXPORT = re.compile(r'(?i)(?:^|/)(?:sessions?|credentials?|service[_-]?account|database[_-]?(?:dump|backup)|user[_-]?(?:export|data))[^/]*\.(?:json|sql|csv|jsonl)$')
MAX_EXPANDED_BYTES = 256 * 1024 * 1024
MAX_ENTRIES = 10000

def check_publication(name, data, depth=0, budget=None):
    """Inspect packed source without extraction; fail closed on unsupported depth/size."""
    if budget is None: budget = {'bytes': 0, 'entries': 0}
    budget['bytes'] += len(data)
    budget['entries'] += 1
    if budget['bytes'] > MAX_EXPANDED_BYTES or budget['entries'] > MAX_ENTRIES:
        return [{'file': name, 'reasons': ['archive inspection limit exceeded']}]
    reasons = []
    member_name = name.rsplit('!', 1)[-1]
    if (RESTRICTED.search(member_name) and member_name != '.env.example') or DATA_EXPORT.search(member_name):
        reasons.append('restricted filename')
    reasons.extend(check_bytes(data))
    if name.lower().endswith(('.exe', '.dll', '.dex')):
        reasons.extend(check_bytes(data.decode('utf-16-le', errors='ignore').encode()))
    findings = [{'file': name, 'reasons': sorted(set(reasons))}] if reasons else []
    packed = data.startswith((b'PK\x03\x04', b'\x1f\x8b', b'\xfd7zXZ')) or name.lower().endswith('.b64')
    if not packed: return findings
    if depth >= 4:
        return findings + [{'file': name, 'reasons': ['archive nesting limit exceeded']}]
    try:
        if name.lower().endswith('.b64'):
            decoded = base64.b64decode(re.sub(rb'\s+', b'', data), validate=True)
            findings.extend(check_publication(name + '!decoded', decoded, depth + 1, budget))
        elif data.startswith(b'PK\x03\x04'):
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                for member in archive.infolist():
                    if member.is_dir(): continue
                    if member.file_size + budget['bytes'] > MAX_EXPANDED_BYTES:
                        return findings + [{'file': name, 'reasons': ['archive inspection limit exceeded']}]
                    findings.extend(check_publication(name + '!' + member.filename, archive.read(member), depth + 1, budget))
                    if budget['entries'] > MAX_ENTRIES: break
        else:
            with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
                for member in archive:
                    if not member.isfile(): continue
                    if member.size + budget['bytes'] > MAX_EXPANDED_BYTES:
                        return findings + [{'file': name, 'reasons': ['archive inspection limit exceeded']}]
                    findings.extend(check_publication(name + '!' + member.name, archive.extractfile(member).read(), depth + 1, budget))
                    if budget['entries'] > MAX_ENTRIES: break
    except (ValueError, OSError, zipfile.BadZipFile, tarfile.TarError):
        findings.append({'file': name, 'reasons': ['unreadable packed publication input']})
    return findings

def check_bytes(data):
    reasons = [label for label, pattern in RULES.items() if re.search(pattern, data)]
    for m in re.finditer(rb'eyJ[A-Za-z0-9_-]{10,8192}\.[A-Za-z0-9_-]{10,8192}\.[A-Za-z0-9_-]{10,8192}', data):
        try:
            part = m.group().split(b'.')[1]
            claims = json.loads(base64.urlsafe_b64decode(part + b'=' * (-len(part) % 4)))
            if claims.get('role') != 'anon': reasons.append('non-anonymous account JWT')
        except (ValueError, TypeError): reasons.append('unrecognized JWT')
    return sorted(set(reasons))

def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
    findings = []
    for name in filter(None, paths):
        findings.extend(check_publication(name, Path(name).read_bytes()))
    print(json.dumps({'checked_files': len([p for p in paths if p]), 'findings': findings}, indent=2))
    return bool(findings)

if __name__ == '__main__': sys.exit(main())
