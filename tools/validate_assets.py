"""Validate assembly data and PNG headers without modifying assets."""
import json
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/gba-indigo'
manifest=json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8'))
expected={'dpad','a','b','l','r','select','start'}

def dimensions(relative):
    path=(ASSETS/relative).resolve()
    assert path.is_relative_to(ASSETS.resolve()), relative
    content=path.read_bytes()
    assert content[:8]==b'\x89PNG\r\n\x1a\n',relative
    width,height,depth,color=struct.unpack('>IIBB',content[16:26])
    assert depth==8 and color==6,(relative,'RGBA PNG required')
    return width,height

def contains(outer,inner):
    return inner['width']>0 and inner['height']>0 and inner['x']>=outer['x'] and inner['y']>=outer['y'] and inner['x']+inner['width']<=outer['x']+outer['width'] and inner['y']+inner['height']<=outer['y']+outer['height']

assert set(manifest['sprites'])==expected
for key,sprite in manifest['sprites'].items():
    assert dimensions(sprite['file'])==(sprite['width'],sprite['height'])
    assert contains({'x':0,'y':0,**{k:sprite[k] for k in ('width','height')}},sprite['contentRect']),key
for key,variant in manifest['variants'].items():
    assert dimensions(variant['file'])==(variant['width'],variant['height'])
    assert set(variant['openings'])==expected,key
    canvas={'x':0,'y':0,'width':variant['width'],'height':variant['height']}
    for rect in [variant['screenOpening'],*variant['openings'].values()]: assert contains(canvas,rect),key
    game=variant['gameRect']
    assert game['width']*2==game['height']*3,(key,'game must be 3:2')
    assert contains(variant['screenOpening'],game),key
preview=(ROOT/'preview/assets.js').read_text(encoding='utf-8')
embedded=json.loads(preview.removeprefix('window.GBA_ASSETS = ').strip().removesuffix(';'))
assert embedded==manifest,'Preview manifest differs from source'
for name in ('index.html','preview.css','preview.js'):assert (ROOT/'preview'/name).is_file()
print('OK: 3 façades, 7 boutons RGBA, fenêtres 3:2, coordonnées et manifeste de prévisualisation.')

# The modern controls are white vectors, with transparent @3x PNGs for UIKit.
import xml.etree.ElementTree as ET
ASSETS = ROOT/'assets/ios-outline'
outline = json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8'))
assert set(outline['icons']) == expected | {'menu'}
for name, icon in outline['icons'].items():
    assert dimensions(icon['png']) == (icon['width']*3, icon['height']*3)
    svg = ET.parse(ASSETS/icon['svg']).getroot()
    assert svg.attrib['fill'] == 'none' and svg.attrib['stroke'] == '#fff'
    assert svg.attrib['viewBox'] == f"0 0 {icon['width']} {icon['height']}"
print('OK: 8 icônes blanches SVG et 8 PNG RGBA @3x.')
