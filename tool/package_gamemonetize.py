"""Validate and package a release web build; never upload or activate a game."""
import argparse
import json
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--build', default='build/web')
parser.add_argument('--output', required=True)
args = parser.parse_args()
root = Path(args.build)
required = ['index.html', 'main.dart.js', 'flutter_bootstrap.js', 'portal-config.js', 'portal-bridge.js']
for name in required:
    if not (root / name).is_file():
        parser.error(f'Missing release file: {name}')
config = (root / 'portal-config.js').read_text()
match = re.search(r'gameId:\s*"([^"]+)"', config)
if not match or not match.group(1).strip() or 'your_game_id' in match.group(1):
    parser.error('A real public GameMonetize GameId is required')
if '<base href="./">' not in (root / 'index.html').read_text():
    parser.error('The portal build must use a relative base URL')
if 'wss://la-ultima-mano.onrender.com/ws' not in (root / 'main.dart.js').read_text():
    parser.error('The public game server was not embedded in the build')
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_name(output.name + '.tmp')
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(root.rglob('*')):
        if not file.is_file() or file.name.endswith('.symbols'):
            continue
        relative = file.relative_to(root)
        if relative.as_posix() == '.last_build_id':
            continue
        if any(part.startswith('.') for part in relative.parts):
            parser.error(f'Unexpected hidden file: {relative}')
        archive.write(file, relative.as_posix())
    archive.write('assets/fonts/OFL.txt', 'licenses/Pixelify-SIL-OFL.txt')
    archive.writestr('CREDITS.txt',
        'La Última Mano\nBased on Sick Seven by Monguit0: https://github.com/Monguit0/sick-seven\n'
        'Linux adaptation and redesign: https://github.com/gokuexe/la-ultima-mano\n'
        'Pixelify Sans: SIL Open Font License (included).\n'
        'Distribution rights are managed by the project maintainer.\n')
with zipfile.ZipFile(temporary) as archive:
    if archive.testzip() is not None or 'index.html' not in archive.namelist():
        parser.error('ZIP integrity check failed')
temporary.replace(output)
print(json.dumps({'zip': str(output.resolve()), 'bytes': output.stat().st_size, 'gameId': match.group(1)}))
