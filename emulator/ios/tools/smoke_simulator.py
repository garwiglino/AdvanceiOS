#!/usr/bin/env python3
"""Launch the built app on a real iOS Simulator and retain its screenshot."""
import json
from pathlib import Path
import subprocess
import time

ios = Path(__file__).resolve().parents[1]
def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()

devices = json.loads(sim('list', 'devices', 'available', '--json'))['devices']
phones = [device for runtime, group in devices.items() if 'iOS' in runtime
          for device in group if device.get('isAvailable') and device['name'].startswith('iPhone')]
assert phones, 'No iPhone simulator installed on this runner'
device = phones[0]
uuid = device['udid']
if device['state'] != 'Booted': sim('boot', uuid)
sim('bootstatus', uuid, '-b')
app = ios / 'build-simulator/Build/Products/Debug-iphonesimulator/mGBA iOS.app'
sim('install', uuid, str(app))
launch = sim('launch', '--terminate-running-process', uuid, 'org.example.mgba.ios')
pid = launch.rsplit(':', 1)[1].strip()
time.sleep(6)
process = subprocess.check_output(['ps', '-p', pid, '-o', 'comm='], text=True)
assert 'mGBA iOS' in process, 'The app did not remain running'
out = ios / 'build-simulator/launcher-simulator.png'
sim('io', uuid, 'screenshot', str(out))
assert out.stat().st_size > 1000
print(f'PASS: app stayed running on {device["name"]}; screenshot: {out}')
