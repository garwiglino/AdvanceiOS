#!/usr/bin/env python3
"""Validate the checked-in OpenStep project and all local inputs on any host."""
import json
from pathlib import Path
import plistlib
import re
import struct
import xml.etree.ElementTree as ET

ios = Path(__file__).resolve().parents[1]
project = ios / 'mGBA-iOS.xcodeproj'
text = (project / 'project.pbxproj').read_text(encoding='utf-8')
tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', text.split('\n',1)[1])
position = 0
def read():
    global position
    token = tokens[position]
    position += 1
    if token == '{':
        value = {}
        while tokens[position] != '}':
            key = read()
            assert tokens[position] == '='
            position += 1
            assert key not in value, f'Duplicate key: {key}'
            value[key] = read()
            assert tokens[position] == ';'
            position += 1
        position += 1
        return value
    if token == '(':
        value = []
        while tokens[position] != ')':
            value.append(read())
            assert tokens[position] == ','
            position += 1
        position += 1
        return value
    return json.loads(token) if token.startswith('"') else token
data = read()
assert position == len(tokens)
objects = data['objects']
assert objects[data['rootObject']]['isa'] == 'PBXProject'
def check_refs(value):
    if isinstance(value, dict):
        for child in value.values(): check_refs(child)
    elif isinstance(value, list):
        for child in value: check_refs(child)
    elif re.fullmatch(r'[0-9A-F]{24}', value):
        assert value in objects, f'Unknown object: {value}'
check_refs(objects)
file_count = 0
source_paths = []
for value in objects.values():
    if value['isa'] == 'PBXFileReference' and value['sourceTree'] == '<group>':
        path = ios / value['path']
        assert path.exists(), f'Missing input: {path}'
        file_count += 1
    if value['isa'] == 'PBXSourcesBuildPhase':
        source_paths = [objects[objects[f]['fileRef']]['path'] for f in value['files']]
assert len(source_paths) == len(set(source_paths))
for relative in json.loads((ios/'CoreSources.json').read_text()):
    assert '../'+relative in source_paths
for file in list((ios/'App').glob('*.m')) + list((ios/'App').glob('*.swift')):
    assert file.relative_to(ios).as_posix() in source_paths
for name in ('Info.plist','PrivacyInfo.xcprivacy'):
    with (ios/'Resources'/name).open('rb') as file: plistlib.load(file)
ET.parse(ios/'Resources/LaunchScreen.storyboard')
scheme = ET.parse(project/'xcshareddata/xcschemes/mGBA iOS.xcscheme')
for reference in scheme.findall('.//BuildableReference'):
    assert objects[reference.attrib['BlueprintIdentifier']]['isa'] == 'PBXNativeTarget'
png = (ios/'Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II',png[16:24]) == (1024,1024) and png[25] == 2
layout = json.loads((ios/'skins/layout.example.json').read_text(encoding='utf-8'))
for profile in layout['profiles']:
    for rect in [profile['screen'], *profile['controls'].values()]:
        x,y,w,h = rect
        assert min(x,y) >= 0 and min(w,h) > 0 and x+w <= 1 and y+h <= 1
print(f'PASS: OpenStep syntax, {len(objects)} object references, {file_count} local inputs, {len(source_paths)} compile units, scheme, plists, storyboard XML, RGB icon and overlay rectangles.')
print('This is structural validation, not an Apple SDK compilation or UIKit runtime test.')
