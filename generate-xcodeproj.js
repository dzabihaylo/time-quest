#!/usr/bin/env node
// Generates a minimal valid project.pbxproj for TimeQuest
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

function uuid() {
  return crypto.randomBytes(12).toString('hex').toUpperCase();
}

// Generate all UUIDs upfront
const ids = {};
function id(name) {
  if (!ids[name]) ids[name] = uuid();
  return ids[name];
}

// Source files
const sourceFiles = [
  { name: 'TimeQuestApp.swift', path: 'App/TimeQuestApp.swift' },
  { name: 'AppDependencies.swift', path: 'App/AppDependencies.swift' },
  { name: 'RoleRouter.swift', path: 'App/RoleRouter.swift' },
  { name: 'Routine.swift', path: 'Models/Routine.swift' },
  { name: 'RoutineTask.swift', path: 'Models/RoutineTask.swift' },
  { name: 'GameSession.swift', path: 'Models/GameSession.swift' },
  { name: 'TaskEstimation.swift', path: 'Models/TaskEstimation.swift' },
  { name: 'RoutineRepository.swift', path: 'Repositories/RoutineRepository.swift' },
  { name: 'SessionRepository.swift', path: 'Repositories/SessionRepository.swift' },
  { name: 'TimeEstimationScorer.swift', path: 'Domain/TimeEstimationScorer.swift' },
  { name: 'FeedbackGenerator.swift', path: 'Domain/FeedbackGenerator.swift' },
  { name: 'CalibrationTracker.swift', path: 'Domain/CalibrationTracker.swift' },
  { name: 'TimeFormatting.swift', path: 'Features/Shared/Components/TimeFormatting.swift' },
  { name: 'PINEntryView.swift', path: 'Features/Shared/Views/PINEntryView.swift' },
  { name: 'PlayerHomeView.swift', path: 'Features/Player/Views/PlayerHomeView.swift' },
  { name: 'ParentDashboardView.swift', path: 'Features/Parent/Views/ParentDashboardView.swift' },
  { name: 'RoutineListView.swift', path: 'Features/Parent/Views/RoutineListView.swift' },
  { name: 'RoutineEditorView.swift', path: 'Features/Parent/Views/RoutineEditorView.swift' },
  { name: 'TaskEditorView.swift', path: 'Features/Parent/Views/TaskEditorView.swift' },
  { name: 'SchedulePickerView.swift', path: 'Features/Parent/Views/SchedulePickerView.swift' },
  { name: 'RoutineEditorViewModel.swift', path: 'Features/Parent/ViewModels/RoutineEditorViewModel.swift' },
];

// Groups
const groups = [
  { name: 'App', path: 'App', files: ['TimeQuestApp.swift', 'AppDependencies.swift', 'RoleRouter.swift'] },
  { name: 'Models', path: 'Models', files: ['Routine.swift', 'RoutineTask.swift', 'GameSession.swift', 'TaskEstimation.swift'] },
  { name: 'Repositories', path: 'Repositories', files: ['RoutineRepository.swift', 'SessionRepository.swift'] },
  { name: 'Domain', path: 'Domain', files: ['TimeEstimationScorer.swift', 'FeedbackGenerator.swift', 'CalibrationTracker.swift'] },
  { name: 'Shared', path: 'Shared', subgroups: ['Components', 'SharedViews'] },
  { name: 'Components', path: 'Components', files: ['TimeFormatting.swift'] },
  { name: 'SharedViews', path: 'Views', files: ['PINEntryView.swift'] },
  { name: 'Player', path: 'Player', subgroups: ['PlayerViews'] },
  { name: 'PlayerViews', path: 'Views', files: ['PlayerHomeView.swift'] },
  { name: 'Parent', path: 'Parent', subgroups: ['ParentViews', 'ParentViewModels'] },
  { name: 'ParentViews', path: 'Views', files: ['ParentDashboardView.swift', 'RoutineListView.swift', 'RoutineEditorView.swift', 'TaskEditorView.swift', 'SchedulePickerView.swift'] },
  { name: 'ParentViewModels', path: 'ViewModels', files: ['RoutineEditorViewModel.swift'] },
  { name: 'Features', path: 'Features', subgroups: ['Player', 'Parent', 'Shared'] },
  { name: 'Resources', path: 'Resources', files: [] },
];

// Build PBXFileReference entries
let fileRefs = '';
let buildFiles = '';
let sourcesBuildPhase = '';
let resourcesBuildPhase = '';

for (const f of sourceFiles) {
  const fileRefId = id(`fileRef_${f.name}`);
  const buildFileId = id(`buildFile_${f.name}`);
  fileRefs += `\t\t${fileRefId} /* ${f.name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${f.name}; sourceTree = "<group>"; };\n`;
  buildFiles += `\t\t${buildFileId} /* ${f.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileRefId} /* ${f.name} */; };\n`;
  sourcesBuildPhase += `\t\t\t\t${buildFileId} /* ${f.name} in Sources */,\n`;
}

// Assets.xcassets
const assetsFileRefId = id('fileRef_Assets');
const assetsBuildFileId = id('buildFile_Assets');
fileRefs += `\t\t${assetsFileRefId} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };\n`;
buildFiles += `\t\t${assetsBuildFileId} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = ${assetsFileRefId} /* Assets.xcassets */; };\n`;
resourcesBuildPhase += `\t\t\t\t${assetsBuildFileId} /* Assets.xcassets in Resources */,\n`;

// Product reference
const productRefId = id('productRef');
fileRefs += `\t\t${productRefId} /* TimeQuest.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TimeQuest.app; sourceTree = BUILT_PRODUCTS_DIR; };\n`;

// Build group children
function groupChildren(g) {
  let children = '';
  if (g.files) {
    for (const fname of g.files) {
      children += `\t\t\t\t${id(`fileRef_${fname}`)} /* ${fname} */,\n`;
    }
  }
  if (g.subgroups) {
    for (const sg of g.subgroups) {
      children += `\t\t\t\t${id(`group_${sg}`)} /* ${sg} */,\n`;
    }
  }
  if (g.name === 'Resources') {
    children += `\t\t\t\t${assetsFileRefId} /* Assets.xcassets */,\n`;
  }
  return children;
}

let groupSections = '';
for (const g of groups) {
  const gid = id(`group_${g.name}`);
  groupSections += `\t\t${gid} /* ${g.name} */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n${groupChildren(g)}\t\t\t);\n\t\t\tpath = ${g.path};\n\t\t\tsourceTree = "<group>";\n\t\t};\n`;
}

// Main group
const mainGroupId = id('mainGroup');
const productsGroupId = id('productsGroup');
groupSections += `\t\t${mainGroupId} = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n`;
groupSections += `\t\t\t\t${id('group_App')} /* App */,\n`;
groupSections += `\t\t\t\t${id('group_Models')} /* Models */,\n`;
groupSections += `\t\t\t\t${id('group_Repositories')} /* Repositories */,\n`;
groupSections += `\t\t\t\t${id('group_Domain')} /* Domain */,\n`;
groupSections += `\t\t\t\t${id('group_Features')} /* Features */,\n`;
groupSections += `\t\t\t\t${id('group_Resources')} /* Resources */,\n`;
groupSections += `\t\t\t\t${productsGroupId} /* Products */,\n`;
groupSections += `\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t};\n`;

// Products group
groupSections += `\t\t${productsGroupId} /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t${productRefId} /* TimeQuest.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t};\n`;

const projectId = id('project');
const targetId = id('target');
const buildConfigListProject = id('buildConfigListProject');
const buildConfigListTarget = id('buildConfigListTarget');
const debugConfigProject = id('debugConfigProject');
const releaseConfigProject = id('releaseConfigProject');
const debugConfigTarget = id('debugConfigTarget');
const releaseConfigTarget = id('releaseConfigTarget');
const sourcesBuildPhaseId = id('sourcesBuildPhase');
const resourcesBuildPhaseId = id('resourcesBuildPhase');
const frameworksBuildPhaseId = id('frameworksBuildPhase');

const pbxproj = `// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 77;
\tobjects = {

/* Begin PBXBuildFile section */
${buildFiles}/* End PBXBuildFile section */

/* Begin PBXFileReference section */
${fileRefs}/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t${frameworksBuildPhaseId} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
${groupSections}/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t${targetId} /* TimeQuest */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${buildConfigListTarget} /* Build configuration list for PBXNativeTarget "TimeQuest" */;
\t\t\tbuildPhases = (
\t\t\t\t${sourcesBuildPhaseId} /* Sources */,
\t\t\t\t${frameworksBuildPhaseId} /* Frameworks */,
\t\t\t\t${resourcesBuildPhaseId} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = TimeQuest;
\t\t\tproductName = TimeQuest;
\t\t\tproductReference = ${productRefId} /* TimeQuest.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t${projectId} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1620;
\t\t\t\tLastUpgradeCheck = 1620;
\t\t\t};
\t\t\tbuildConfigurationList = ${buildConfigListProject} /* Build configuration list for PBXProject "TimeQuest" */;
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = ${mainGroupId};
\t\t\tproductRefGroup = ${productsGroupId} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t${targetId} /* TimeQuest */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t${resourcesBuildPhaseId} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${resourcesBuildPhase}\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t${sourcesBuildPhaseId} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
${sourcesBuildPhase}\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t${debugConfigProject} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASCLOPTIMIZE = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${releaseConfigProject} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASCLOPTIMIZE = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t${debugConfigTarget} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = TimeQuest;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.timequest.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${releaseConfigTarget} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = TimeQuest;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.timequest.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t${buildConfigListProject} /* Build configuration list for PBXProject "TimeQuest" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${debugConfigProject} /* Debug */,
\t\t\t\t${releaseConfigProject} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t${buildConfigListTarget} /* Build configuration list for PBXNativeTarget "TimeQuest" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${debugConfigTarget} /* Debug */,
\t\t\t\t${releaseConfigTarget} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = ${projectId} /* Project object */;
}
`;

const outputPath = path.join(__dirname, 'TimeQuest', 'TimeQuest.xcodeproj', 'project.pbxproj');
fs.writeFileSync(outputPath, pbxproj, 'utf8');
console.log(`Generated ${outputPath}`);

// Also generate xcschemes
const schemesDir = path.join(__dirname, 'TimeQuest', 'TimeQuest.xcodeproj', 'xcshareddata', 'xcschemes');
fs.mkdirSync(schemesDir, { recursive: true });

const scheme = `<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1620"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      runPostActionsOnFailure = "NO">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "${targetId}"
               BuildableName = "TimeQuest.app"
               BlueprintName = "TimeQuest"
               ReferencedContainer = "container:TimeQuest.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "${targetId}"
            BuildableName = "TimeQuest.app"
            BlueprintName = "TimeQuest"
            ReferencedContainer = "container:TimeQuest.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "${targetId}"
            BuildableName = "TimeQuest.app"
            BlueprintName = "TimeQuest"
            ReferencedContainer = "container:TimeQuest.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
`;

fs.writeFileSync(path.join(schemesDir, 'TimeQuest.xcscheme'), scheme, 'utf8');
console.log('Generated scheme file');
