#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; no machine-specific signing data."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent
uid=lambda name:hashlib.sha256(name.encode()).hexdigest()[:24].upper()
objects={}
def obj(name,body):
 key=uid(name);objects[key]=body;return key
sources=sorted((root/'ScreenshotTool').glob('*.swift'))
tests=sorted((root/'ScreenshotToolTests').glob('*.swift'))
refs=[];testrefs=[];builds=[];testbuilds=[]
for paths,rr,bb in [(sources,refs,builds),(tests,testrefs,testbuilds)]:
 for p in paths:
  key=str(p.relative_to(root));r=obj(key,'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+p.name+'"; sourceTree = "<group>";');rr.append(r)
  bb.append(obj('build:'+key,'isa = PBXBuildFile; fileRef = '+r+';'))
arr=lambda xs:'('+','.join(xs)+')'
appProduct=obj('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = ScreenshotToolNative.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = ScreenshotToolTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
info=obj('info','isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
assets=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
assetBuild=obj('assetbuild','isa = PBXBuildFile; fileRef = '+assets+';')
appGroup=obj('appGroup','isa = PBXGroup; children = '+arr(refs+[info,assets])+'; path = ScreenshotTool; sourceTree = "<group>";')
testGroup=obj('testGroup','isa = PBXGroup; children = '+arr(testrefs)+'; path = ScreenshotToolTests; sourceTree = "<group>";')
products=obj('products','isa = PBXGroup; children = '+arr([appProduct,testProduct])+'; name = Products; sourceTree = "<group>";')
main=obj('main','isa = PBXGroup; children = '+arr([appGroup,testGroup,products])+'; sourceTree = "<group>";')
def phase(name,kind,files=[]):return obj(name,'isa = '+kind+'; buildActionMask = 2147483647; files = '+arr(files)+'; runOnlyForDeploymentPostprocessing = 0;')
appPhases=[phase('appSources','PBXSourcesBuildPhase',builds),phase('appFrameworks','PBXFrameworksBuildPhase'),phase('appResources','PBXResourcesBuildPhase',[assetBuild])]
testPhases=[phase('testSources','PBXSourcesBuildPhase',testbuilds),phase('testFrameworks','PBXFrameworksBuildPhase'),phase('testResources','PBXResourcesBuildPhase')]
def configs(name,values):
 ids=[]
 for kind in ['Debug','Release']:
  v=dict(values)
  v.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if kind=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if kind=='Debug' else '', 'DEBUG_INFORMATION_FORMAT':'dwarf' if kind=='Debug' else 'dwarf-with-dsym'})
  if kind=='Debug':v['ENABLE_TESTABILITY']='YES'
  body=' '.join(k+' = "'+str(val)+'";' for k,val in v.items())
  ids.append(obj(name+kind,'isa = XCBuildConfiguration; buildSettings = { '+body+' }; name = '+kind+';'))
 return obj(name+'list','isa = XCConfigurationList; buildConfigurations = '+arr(ids)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'18.0','SWIFT_VERSION':'5.0','TARGETED_DEVICE_FAMILY':'2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic'}
projectConfigs=configs('project',common)
appConfigs=configs('app',{'PRODUCT_NAME':'ScreenshotToolNative','PRODUCT_BUNDLE_IDENTIFIER':'com.mcallers.screenshottool.ipad','INFOPLIST_FILE':'ScreenshotTool/Info.plist','MARKETING_VERSION':'0.5.0','CURRENT_PROJECT_VERSION':'13','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO'})
testConfigs=configs('test',{'PRODUCT_NAME':'ScreenshotToolTests','PRODUCT_BUNDLE_IDENTIFIER':'com.mcallers.screenshottool.ipad.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/ScreenshotToolNative.app/ScreenshotToolNative','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
app=obj('appTarget','isa = PBXNativeTarget; buildConfigurationList = '+appConfigs+'; buildPhases = '+arr(appPhases)+'; buildRules = (); dependencies = (); name = ScreenshotToolNative; productName = ScreenshotToolNative; productReference = '+appProduct+'; productType = "com.apple.product-type.application";')
proxy=obj('proxy','isa = PBXContainerItemProxy; containerPortal = '+uid('projectRoot')+'; proxyType = 1; remoteGlobalIDString = '+app+'; remoteInfo = ScreenshotToolNative;')
dep=obj('dependency','isa = PBXTargetDependency; target = '+app+'; targetProxy = '+proxy+';')
test=obj('testTarget','isa = PBXNativeTarget; buildConfigurationList = '+testConfigs+'; buildPhases = '+arr(testPhases)+'; buildRules = (); dependencies = '+arr([dep])+'; name = ScreenshotToolTests; productName = ScreenshotToolTests; productReference = '+testProduct+'; productType = "com.apple.product-type.bundle.unit-test";')
project=obj('projectRoot','isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = { '+test+' = { TestTargetID = '+app+'; }; }; }; buildConfigurationList = '+projectConfigs+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([app,test])+';')
(root/'ScreenshotTool.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(k+' = { '+v+' };\n' for k,v in objects.items())+'}; rootObject = '+project+'; }\n')
def ref(target,product,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:ScreenshotTool.xcodeproj"/>'
appref=ref(app,'ScreenshotToolNative.app','ScreenshotToolNative');testref=ref(test,'ScreenshotToolTests.xctest','ScreenshotToolTests')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{testref}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
(root/'ScreenshotTool.xcodeproj/xcshareddata/xcschemes/ScreenshotTool.xcscheme').write_text(scheme)
print('Generated ScreenshotTool.xcodeproj')
