"""Check publication inputs without displaying matched sensitive values."""
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

RULES = {
    'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'provider secret': rb'(?:pdl_(?:sdbx|live)_[A-Za-z0-9_]{16,512}|sb_secret_[A-Za-z0-9_-]{16,512}|gh[pousr]_[A-Za-z0-9]{20,512}|github_pat_[A-Za-z0-9_]{30,512}|AKIA[A-Z0-9]{16}|GOCSPX-[A-Za-z0-9_-]{20,128})',
    'personal email': rb'@(?:gmail|hotmail|outlook|yahoo)\.[A-Za-z]{2,12}',
    'developer path': rb'[A-Za-z]:[/\\]Users[/\\][A-Za-z0-9_. -]{1,128}[/\\]',
    'literal account credential': rb'(?i)(?:access_token|refresh_token|service_role_key|api_secret|client_secret|webhook_secret|storePassword|keyPassword)\s*[=:]\s*[\x22\x27][A-Za-z0-9_./+=-]{12,512}[\x22\x27]',
}
RESTRICTED = re.compile(r'(?i)(?:^|/)(?:\.env(?:\..*)?|local\.properties|.*(?:keystore|private[_-]?key).*\.(?:b64|txt)|.*\.(?:jks|keystore|pfx|p12|key|pdb))$')

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
        reasons = []
        if RESTRICTED.search(name) and name != '.env.example': reasons.append('restricted filename')
        data = Path(name).read_bytes()
        reasons.extend(check_bytes(data))
        if name.lower().endswith(('.exe', '.dll', '.dex')): reasons.extend(check_bytes(data.decode('utf-16-le', errors='ignore').encode()))
        if reasons: findings.append({'file': name, 'reasons': sorted(set(reasons))})
    print(json.dumps({'checked_files': len([p for p in paths if p]), 'findings': findings}, indent=2))
    return bool(findings)

if __name__ == '__main__': sys.exit(main())
