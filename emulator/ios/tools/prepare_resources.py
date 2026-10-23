#!/usr/bin/env python3
"""Generate plists and an original geometric app icon, without dependencies."""
from pathlib import Path
import json
import plistlib
import struct
import zlib

ios = Path(__file__).resolve().parents[1]
root = ios.parent
resources = ios / 'Resources'
resources.mkdir(exist_ok=True)
def plist(name, value):
    (resources / name).write_bytes(plistlib.dumps(value, sort_keys=False))
plist('Info.plist', {
    'CFBundleDevelopmentRegion':'fr', 'CFBundleDisplayName':'mGBA iOS',
    'CFBundleExecutable':'$(EXECUTABLE_NAME)', 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)',
    'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'$(MARKETING_VERSION)',
    'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS':True,
    'UILaunchStoryboardName':'LaunchScreen', 'UIFileSharingEnabled':True,
    'LSSupportsOpeningDocumentsInPlace':True,
    'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
    'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
    'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,
        'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Default','UISceneDelegateClassName':'MGBASceneDelegate'}]}},
    'ITSAppUsesNonExemptEncryption':False,
    'UTImportedTypeDeclarations':[
        {'UTTypeIdentifier':'org.mgba.rom.gba','UTTypeDescription':'Game Boy Advance ROM','UTTypeConformsTo':['public.data'],'UTTypeTagSpecification':{'public.filename-extension':['gba']}},
        {'UTTypeIdentifier':'org.mgba.rom.gb','UTTypeDescription':'Game Boy ROM','UTTypeConformsTo':['public.data'],'UTTypeTagSpecification':{'public.filename-extension':['gb','gbc']}}
    ]
})
plist('PrivacyInfo.xcprivacy', {
    'NSPrivacyTracking':False, 'NSPrivacyTrackingDomains':[], 'NSPrivacyCollectedDataTypes':[],
    'NSPrivacyAccessedAPITypes':[
        {'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryFileTimestamp','NSPrivacyAccessedAPITypeReasons':['C617.1','3B52.1']}
    ]
})
licenses = 'mGBA iOS — port indépendant\n\nMoteur mGBA 0.10.5 : Jeffrey Pfau et contributeurs, MPL-2.0.\nCode du port iOS : MPL-2.0.\nblip_buf : Shay Green, LGPL-2.1-or-later.\ninih : Ben Hoyt, BSD-3-Clause.\n\nLe projet complet distribué avec cette application contient les sources du moteur,\ndu port et des bibliothèques liées, permettant leur modification et reconstruction.\n\n'
for title, path in [('mGBA / port iOS — MPL 2.0',root/'LICENSE'), ('blip_buf — LGPL 2.1',root/'res/licenses/blip_buf.txt'), ('inih — BSD',root/'res/licenses/inih.txt')]:
    licenses += '\n' + title + '\n' + '='*60 + '\n' + path.read_text(encoding='utf-8') + '\n'
(resources / 'Licenses.txt').write_text(licenses, encoding='utf-8')
(resources / 'LaunchScreen.storyboard').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="23000" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="launch">
<device id="retina6_12" orientation="portrait" appearance="dark"/>
<dependencies><plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="23000"/><capability name="Safe area layout guides" minToolsVersion="9.0"/><capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/></dependencies>
<scenes><scene sceneID="scene"><objects><viewController id="launch" sceneMemberID="viewController"><view key="view" contentMode="scaleToFill" id="background"><rect key="frame" x="0.0" y="0.0" width="393" height="852"/><viewLayoutGuide key="safeArea" id="safe"/><color key="backgroundColor" red="0.035" green="0.045" blue="0.065" alpha="1" colorSpace="custom" customColorSpace="sRGB"/></view></viewController><placeholder placeholderIdentifier="IBFirstResponder" id="first" sceneMemberID="firstResponder"/></objects></scene></scenes></document>''', encoding='utf-8')

# This icon is a new code-drawn UI asset; it does not modify mGBA's artwork.
width = 1024
pixels = bytearray(bytes((9, 12, 19)) * width * width)
def rounded(x, y, w, h, radius, color):
    for py in range(y, y+h):
        dy = max(y+radius-py, 0, py-(y+h-radius-1))
        for px in range(x, x+w):
            dx = max(x+radius-px, 0, px-(x+w-radius-1))
            if dx*dx+dy*dy <= radius*radius:
                i = (py*width+px)*3
                pixels[i:i+3] = bytes(color)
rounded(128, 150, 768, 724, 96, (53, 94, 85))
rounded(128, 128, 768, 724, 96, (99, 220, 174))
rounded(207, 202, 610, 392, 42, (12, 27, 32))
rounded(244, 239, 536, 318, 12, (153, 189, 106))
rounded(298, 293, 428, 210, 8, (139, 175, 95))
rounded(220, 678, 202, 66, 12, (12, 27, 32))
rounded(288, 610, 66, 202, 12, (12, 27, 32))
rounded(700, 626, 96, 96, 48, (12, 27, 32))
rounded(584, 698, 96, 96, 48, (12, 27, 32))
def chunk(kind, data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
raw = b''.join(b'\x00'+pixels[y*width*3:(y+1)*width*3] for y in range(width))
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,width,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
assets = resources / 'Assets.xcassets'
icon = assets / 'AppIcon.appiconset'
icon.mkdir(parents=True, exist_ok=True)
(icon/'AppIcon.png').write_bytes(png)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}, indent=2))
(icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'xcode','version':1}}, indent=2))
print('Resources, notices, privacy manifest and opaque 1024px icon generated.')
