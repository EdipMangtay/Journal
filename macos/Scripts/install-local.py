#!/usr/bin/env python3
"""Install the locally built app and pin a single Dock entry without replacing other tiles."""
from pathlib import Path
import plistlib
import subprocess
from urllib.parse import unquote, urlparse

root = Path(__file__).resolve().parent.parent
source = root / 'build/local/Liquidity Edge.app'
destination = Path.home() / 'Applications/Liquidity Edge.app'
if not (source / 'Contents/MacOS/Liquidity Edge').is_file():
    raise SystemExit('Build the local app first using Scripts/build-local.sh')
destination.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['/usr/bin/ditto', str(source), str(destination)], check=True)
subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(destination)], check=True)
raw = subprocess.check_output(['/usr/bin/defaults', 'export', 'com.apple.dock', '-'])
preferences = plistlib.loads(raw)
tiles = preferences.get('persistent-apps', [])
exists = any(unquote(urlparse(tile.get('tile-data', {}).get('file-data', {}).get('_CFURLString', '')).path).rstrip('/') == str(destination) for tile in tiles)
if not exists:
    entry = '{ "tile-data" = { "file-data" = { "_CFURLString" = "' + destination.as_uri() + '/"; "_CFURLStringType" = 15; }; "file-label" = "LIQUIDITY EDGE"; "bundle-identifier" = "com.liquidityedge.journal"; }; "tile-type" = "file-tile"; }'
    subprocess.run(['/usr/bin/defaults', 'write', 'com.apple.dock', 'persistent-apps', '-array-add', entry], check=True)
    subprocess.run(['/usr/bin/killall', 'Dock'], check=False)
subprocess.run(['/usr/bin/open', str(destination)], check=True)
verified = plistlib.loads(subprocess.check_output(['/usr/bin/defaults', 'export', 'com.apple.dock', '-']))
assert any(unquote(urlparse(tile.get('tile-data', {}).get('file-data', {}).get('_CFURLString', '')).path).rstrip('/') == str(destination) for tile in verified.get('persistent-apps', [])), 'Dock entry could not be verified'
print('Installed: ' + str(destination))
print('Dock entry: verified')
print('Launch: requested successfully')
