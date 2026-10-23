#!/usr/bin/env python3
"""Build and run the exact portable core/bridge used by the Xcode target."""
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ios = Path(__file__).resolve().parents[1]
root = ios.parent
compiler = os.environ.get('CC', 'cc')
if os.name == 'nt' and compiler == 'cc':
    compiler = r'C:\msys64\mingw64\bin\gcc.exe'
    os.environ['PATH'] = str(Path(compiler).parent) + os.pathsep + os.environ['PATH']
out = ios / 'build-tests-portable'
out.mkdir(exist_ok=True)
sources = [root / p for p in json.loads((ios / 'CoreSources.json').read_text())]
sources += list((ios / 'Bridge').glob('*.c')) + [ios / 'tests/core_tests.c']
flags = ['-std=gnu11', '-O2', '-g', '-UNDEBUG', '-Werror=implicit-function-declaration',
         '-DM_CORE_GBA', '-DM_CORE_GB', '-DMINIMAL_CORE=2', '-DDISABLE_THREADING',
         '-DUSE_VFS_FILE', '-DBUILD_STATIC', '-DHAVE_STRDUP', '-D_GNU_SOURCE',
         '-I' + str(root / 'include'), '-I' + str(root / 'src'), '-I' + str(ios / 'Bridge')]
if os.name != 'nt':
    flags += ['-DHAVE_STRNDUP', '-DHAVE_LOCALTIME_R']
if sys.platform == 'darwin':
    flags += ['-DHAVE_STRLCPY', '-DHAVE_LOCALE', '-DHAVE_XLOCALE', '-DHAVE_SNPRINTF_L', '-DHAVE_STRTOF_L']
header_mtime = max(p.stat().st_mtime for folder in (root / 'include', root / 'src', ios / 'Bridge', ios / 'tests') for p in folder.rglob('*.h'))
def compile_one(item):
    i, src = item
    obj = out / (hashlib.sha256(str(src.relative_to(root)).encode()).hexdigest()[:20] + '.o')
    if obj.exists() and obj.stat().st_mtime > max(src.stat().st_mtime, Path(__file__).stat().st_mtime, header_mtime):
        return str(obj)
    result = subprocess.run([compiler, *flags, '-c', str(src), '-o', str(obj)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(str(src) + '\n' + result.stdout + result.stderr)
    return str(obj)
with ThreadPoolExecutor(max_workers=min(6, os.cpu_count() or 2)) as pool:
    objects = list(pool.map(compile_one, enumerate(sources)))
exe = out / ('core_tests.exe' if os.name == 'nt' else 'core_tests')
libs = ['-lws2_32', '-lshlwapi'] if os.name == 'nt' else ['-lm']
if sys.platform == 'darwin':
    libs += ['-framework', 'CoreFoundation']
subprocess.run([compiler, *objects, *libs, '-o', str(exe)], check=True)
subprocess.run([str(exe), str(ios / 'tests/ios-smoke-test.gba'), str(out / 'launcher-preview.ppm')], check=True)
print(f'Compiled and tested {len(sources)} source files with {compiler}')
