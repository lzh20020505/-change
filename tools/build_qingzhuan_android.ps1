$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EnvironmentRoot = 'D:\Flutter_Android_Huanjing'
$CacheRoot = 'D:\QingZhuan_GouJian_HuanCun'

$FlutterHome = Join-Path $EnvironmentRoot 'flutter'
$AndroidHome = Join-Path $EnvironmentRoot 'android_sdk'
$JdkParent = Join-Path $EnvironmentRoot 'jdk17_full'
$JdkRoot = Get-ChildItem -LiteralPath $JdkParent -Directory |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
  Select-Object -First 1

if (-not $JdkRoot) {
  throw "Could not find Java under $JdkParent."
}

New-Item -ItemType Directory -Force -Path `
  $CacheRoot, `
  (Join-Path $CacheRoot 'Gradle'), `
  (Join-Path $CacheRoot 'Pub'), `
  (Join-Path $CacheRoot 'Temp'), `
  (Join-Path $CacheRoot 'Flutter_Config') | Out-Null

$env:FLUTTER_HOME = $FlutterHome
$env:ANDROID_HOME = $AndroidHome
$env:ANDROID_SDK_ROOT = $AndroidHome
$env:JAVA_HOME = $JdkRoot.FullName
$env:GRADLE_USER_HOME = Join-Path $CacheRoot 'Gradle'
$env:PUB_CACHE = Join-Path $CacheRoot 'Pub'
$env:TEMP = Join-Path $CacheRoot 'Temp'
$env:TMP = $env:TEMP
$env:LOCALAPPDATA = Join-Path $CacheRoot 'Flutter_Config'
$env:APPDATA = Join-Path $CacheRoot 'Flutter_Config'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:Path = "$FlutterHome\bin;$env:JAVA_HOME\bin;$AndroidHome\platform-tools;$env:Path"

Set-Location -LiteralPath $ProjectRoot

Write-Host 'Running flutter pub get...'
& (Join-Path $FlutterHome 'bin\flutter.bat') pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Running flutter analyze...'
& (Join-Path $FlutterHome 'bin\flutter.bat') analyze
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Running flutter test...'
& (Join-Path $FlutterHome 'bin\flutter.bat') test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building debug APK...'
& (Join-Path $FlutterHome 'bin\flutter.bat') build apk `
  --debug `
  --split-per-abi `
  --target-platform android-arm,android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building release APK...'
& (Join-Path $FlutterHome 'bin\flutter.bat') build apk `
  --release `
  --split-per-abi `
  --target-platform android-arm,android-arm64
exit $LASTEXITCODE
