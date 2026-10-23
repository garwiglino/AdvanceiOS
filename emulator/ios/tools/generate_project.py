#!/usr/bin/env python3
"""Deterministic Xcode project. Python is needed only to regenerate it."""
from pathlib import Path
import hashlib
import json
import plistlib
import re

IOS = Path(__file__).resolve().parents[1]
ROOT = IOS.parent


def core_sources():
    paths = []
    for folder in ('arm', 'core', 'gba', 'gb', 'sm83', 'util'):
        cmake = (ROOT / 'src' / folder / 'CMakeLists.txt').read_text()
        def expand(name):
            block = re.search(r'set\(' + name + r'\s+([^)]*)\)', cmake).group(1)
            result = []
            for token in block.split():
                if token.startswith('${'):
                    result += expand(token[2:-1])
                else:
                    result.append((ROOT / 'src' / folder / token).resolve().relative_to(ROOT).as_posix())
            return result
        paths += expand('SOURCE_FILES')
    paths += ['src/util/memory.c', 'src/util/vfs/vfs-mem.c', 'src/util/vfs/vfs-fifo.c',
              'src/util/vfs/vfs-file.c', 'src/third-party/inih/ini.c', 'src/third-party/blip_buf/blip_buf.c']
    return sorted(set(paths))


def uid(text):
    return hashlib.sha1(text.encode()).hexdigest()[:24].upper()


def pbx(value, level=0):
    pad = '\t' * level
    if isinstance(value, dict):
        return '{\n' + ''.join(pad + '\t' + json.dumps(k) + ' = ' + pbx(v, level + 1) + ';\n' for k, v in value.items()) + pad + '}'
    if isinstance(value, list):
        return '(\n' + ''.join(pad + '\t' + pbx(v, level + 1) + ',\n' for v in value) + pad + ')'
    return json.dumps(str(value), ensure_ascii=False)


def generate():
    sources = core_sources()
    (IOS / 'CoreSources.json').write_text(json.dumps(sources, indent=2) + '\n')
    version = ROOT.joinpath('src/core/version.c.in').read_text()
    for key, val in {'GIT_COMMIT':'', 'GIT_COMMIT_SHORT':'', 'GIT_BRANCH':'release/0.10.5',
                     'GIT_REV':'0', 'BINARY_NAME':'mgba-ios', 'PROJECT_NAME':'mGBA', 'VERSION_STRING':'0.10.5'}.items():
        version = version.replace('${' + key + '}', val)
    (IOS / 'Bridge' / 'version.c').write_text(version)
    objects = {}
    def obj(key, isa, **props):
        ident = uid(key)
        objects[ident] = dict(isa=isa, **props)
        return ident
    def ref(path, kind):
        return obj('file:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
    compile_files = ['../' + p for p in sources] + [p.relative_to(IOS).as_posix() for p in sorted((IOS / 'Bridge').glob('*.c'))] + [p.relative_to(IOS).as_posix() for p in sorted(list((IOS / 'App').glob('*.m')) + list((IOS / 'App').glob('*.swift')))]
    source_refs, builds = [], []
    for path in compile_files:
        r = ref(path, 'sourcecode.swift' if path.endswith('.swift') else 'sourcecode.c.objc' if path.endswith('.m') else 'sourcecode.c.c')
        source_refs.append(r)
        builds.append(obj('build:' + path, 'PBXBuildFile', fileRef=r))
    for path in sorted(IOS.glob('**/*.h')):
        source_refs.append(ref(path.relative_to(IOS).as_posix(), 'sourcecode.c.h'))
    resources = ['Resources/Assets.xcassets', 'Resources/PrivacyInfo.xcprivacy', 'Resources/LaunchScreen.storyboard', 'Resources/Licenses.txt', '../../assets/gba-indigo']
    resource_refs, resource_builds = [], []
    for path in resources:
        kind = 'folder' if path.endswith('gba-indigo') else 'folder.assetcatalog' if path.endswith('xcassets') else 'file.storyboard' if path.endswith('storyboard') else 'text.xml' if path.endswith('xcprivacy') else 'text'
        r = ref(path, kind)
        resource_refs.append(r)
        resource_builds.append(obj('build:' + path, 'PBXBuildFile', fileRef=r))
    resource_refs.append(ref('Resources/Info.plist', 'text.plist.xml'))
    frameworks, framework_builds = [], []
    for name in ('UIKit', 'Foundation', 'CoreFoundation', 'CoreGraphics', 'QuartzCore', 'AVFoundation', 'GameController', 'UniformTypeIdentifiers', 'SwiftUI'):
        r = obj('framework:' + name, 'PBXFileReference', lastKnownFileType='wrapper.framework', name=name + '.framework', path='System/Library/Frameworks/' + name + '.framework', sourceTree='SDKROOT')
        frameworks.append(r)
        framework_builds.append(obj('frameworkbuild:' + name, 'PBXBuildFile', fileRef=r))
    product = obj('product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='mGBA iOS.app', sourceTree='BUILT_PRODUCTS_DIR')
    product_group = obj('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
    group = obj('group', 'PBXGroup', children=[obj('sources', 'PBXGroup', children=source_refs, name='Sources', sourceTree='<group>'), obj('resources', 'PBXGroup', children=resource_refs, name='Resources', sourceTree='<group>'), obj('frameworks', 'PBXGroup', children=frameworks, name='Frameworks', sourceTree='<group>'), product_group], sourceTree='<group>')
    phases = [obj('sourcesphase', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0), obj('frameworkphase', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=framework_builds, runOnlyForDeploymentPostprocessing=0), obj('resourcephase', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)]
    def configs(name, settings):
        ids = []
        for mode in ('Debug', 'Release'):
            s = dict(settings)
            s.update(GCC_OPTIMIZATION_LEVEL='0' if mode == 'Debug' else '3', DEBUG_INFORMATION_FORMAT='dwarf' if mode == 'Debug' else 'dwarf-with-dsym', ONLY_ACTIVE_ARCH='YES' if mode == 'Debug' else 'NO')
            s['GCC_PREPROCESSOR_DEFINITIONS'] = list(s.get('GCC_PREPROCESSOR_DEFINITIONS', ['$(inherited)'])) + (['DEBUG=1'] if mode == 'Debug' else ['NDEBUG=1'])
            ids.append(obj(name + mode, 'XCBuildConfiguration', buildSettings=s, name=mode))
        return obj(name + 'configs', 'XCConfigurationList', buildConfigurations=ids, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    settings = dict(SWIFT_VERSION='5.0', SWIFT_OBJC_BRIDGING_HEADER='App/AdvanceiOS-Bridging-Header.h', SWIFT_OBJC_INTERFACE_HEADER_NAME='AdvanceiOS-Swift.h', PRODUCT_MODULE_NAME='AdvanceiOS', ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES='YES', CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES', CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF='YES', GCC_C_LANGUAGE_STANDARD='gnu11', SDKROOT='iphoneos', IPHONEOS_DEPLOYMENT_TARGET='16.0', SUPPORTED_PLATFORMS='iphoneos iphonesimulator', TARGETED_DEVICE_FAMILY='1,2', SUPPORTS_MACCATALYST='NO', SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD='NO', CODE_SIGN_STYLE='Automatic', ENABLE_USER_SCRIPT_SANDBOXING='YES', HEADER_SEARCH_PATHS=['$(inherited)', '$(SRCROOT)/../include', '$(SRCROOT)/../src', '$(SRCROOT)/Bridge'], GCC_PREPROCESSOR_DEFINITIONS=['$(inherited)', 'M_CORE_GBA', 'M_CORE_GB', 'MINIMAL_CORE=2', 'DISABLE_THREADING', 'USE_VFS_FILE', 'BUILD_STATIC', '_DARWIN_C_SOURCE', 'HAVE_STRDUP', 'HAVE_STRNDUP', 'HAVE_STRLCPY', 'HAVE_LOCALTIME_R', 'HAVE_LOCALE', 'HAVE_XLOCALE', 'HAVE_SNPRINTF_L', 'HAVE_STRTOF_L'], OTHER_CFLAGS=['$(inherited)', '-Werror=implicit-function-declaration'], PRODUCT_BUNDLE_IDENTIFIER='org.example.mgba.ios', PRODUCT_NAME='mGBA iOS', INFOPLIST_FILE='Resources/Info.plist', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', CURRENT_PROJECT_VERSION='1', MARKETING_VERSION='1.0', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks'], ENABLE_BITCODE='NO')
    target = obj('target', 'PBXNativeTarget', buildConfigurationList=configs('target', settings), buildPhases=phases, buildRules=[], dependencies=[], name='mGBA iOS', productName='mGBA iOS', productReference=product, productType='com.apple.product-type.application')
    project = obj('project', 'PBXProject', attributes={'BuildIndependentTargetsInParallel':'YES', 'LastUpgradeCheck':'1600', 'TargetAttributes': {target: {'CreatedOnToolsVersion':'16.0'}}}, buildConfigurationList=configs('project', {}), compatibilityVersion='Xcode 14.0', developmentRegion='fr', hasScannedForEncodings=0, knownRegions=['fr', 'en', 'Base'], mainGroup=group, productRefGroup=product_group, projectDirPath='', projectRoot='', targets=[target])
    out = IOS / 'mGBA-iOS.xcodeproj'
    out.mkdir(exist_ok=True)
    (out / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + pbx(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project)) + '\n', encoding='utf-8')
    schemes = out / 'xcshareddata' / 'xcschemes'
    schemes.mkdir(parents=True, exist_ok=True)
    buildref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="mGBA iOS.app" BlueprintName="mGBA iOS" ReferencedContainer="container:mGBA-iOS.xcodeproj"/>'
    (schemes / 'mGBA iOS.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
    for path in compile_files:
        assert (IOS / path).is_file(), path
    print(f'Generated {out.name}: {len(compile_files)} sources, {len(objects)} objects')

if __name__ == '__main__':
    generate()
