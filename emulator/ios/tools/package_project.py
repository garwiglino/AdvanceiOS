#!/usr/bin/env python3
"""Package the complete source tree, excluding host build outputs."""
from pathlib import Path
import hashlib
import zipfile

ios = Path(__file__).resolve().parents[1]
root = ios.parent.parent
output = root.parent / 'mGBA-iOS-Xcode.zip'
files = []
for file in sorted(root.rglob('*')):
    if not file.is_file():
        continue
    parts = file.relative_to(root).parts
    if any(p in ('.git','__pycache__','xcuserdata') or p.startswith('build-') for p in parts):
        continue
    if file.suffix in ('.pyc', '.xcuserstate', '.zip') or file.name == '.DS_Store':
        continue
    files.append(file)
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for file in files:
        archive.write(file, 'AdvanceiOS/' + file.relative_to(root).as_posix())
with zipfile.ZipFile(output) as archive:
    assert len(archive.namelist()) == len(files)
    assert archive.testzip() is None
    assert 'AdvanceiOS/emulator/ios/mGBA-iOS.xcodeproj/project.pbxproj' in archive.namelist()
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(digest + '  ' + output.name + '\n')
print(f'{output}\n{len(files)} files; {output.stat().st_size / 1024**2:.1f} MiB; ZIP integrity verified\nSHA-256 {digest}')
