$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$InstallRoot = 'D:\Flutter_Android_Huanjing'
$DownloadsDir = Join-Path $InstallRoot 'downloads'
$FlutterHome = Join-Path $InstallRoot 'flutter'
$AndroidSdk = Join-Path $InstallRoot 'android_sdk'
$JdkRoot = Join-Path $InstallRoot 'jdk17_full'
$JdkHome = $JdkRoot
$GradleUserHome = Join-Path $InstallRoot 'gradle_home'
$ScriptsDir = Join-Path $InstallRoot 'scripts'

$FlutterVersion = '3.44.0'
$FlutterZip = Join-Path $DownloadsDir "flutter_windows_$FlutterVersion-stable.zip"
$FlutterStorageBaseUrl = 'https://storage.flutter-io.cn'
$FlutterUrl = "$FlutterStorageBaseUrl/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"

$AndroidToolsVersion = '14742923'
$AndroidToolsZip = Join-Path $DownloadsDir "commandlinetools-win-$AndroidToolsVersion`_latest.zip"
$AndroidToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-$AndroidToolsVersion`_latest.zip"

$JdkZip = Join-Path $DownloadsDir 'microsoft-jdk-17.0.19-windows-x64.zip'
$JdkUrl = 'https://aka.ms/download-jdk/microsoft-jdk-17.0.19-windows-x64.zip'
$BundledJdkCandidate = 'D:\idea\IntelliJ IDEA 2023.2.2\jbr'

function Ensure-Directory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Test-ZipArchive {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $false
  }

  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    $Zip.Dispose()
    return $true
  }
  catch {
    return $false
  }
}

function Download-FileIfMissing {
  param(
    [string]$Url,
    [string]$OutFile,
    [string]$Name
  )

  $HasPartialFile = (Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)
  if ($HasPartialFile -and (Test-ZipArchive -Path $OutFile)) {
    Write-Host "$Name already downloaded and verified: $OutFile"
    return
  }

  if ($HasPartialFile) {
    Write-Host "Resuming incomplete $Name download..."
    & curl.exe -L --fail --retry 3 --retry-delay 5 --connect-timeout 30 -C - --output $OutFile $Url
  }
  else {
    Write-Host "Downloading $Name..."
    & curl.exe -L --fail --retry 3 --retry-delay 5 --connect-timeout 30 --output $OutFile $Url
  }

  if ($LASTEXITCODE -ne 0) {
    Write-Host "Resume/download failed for $Name. Trying a clean overwrite download..."
    & curl.exe -L --fail --retry 3 --retry-delay 5 --connect-timeout 30 --output $OutFile $Url
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to download $Name from $Url"
    }
  }
  if ((Get-Item -LiteralPath $OutFile).Length -eq 0) {
    throw "$Name download produced a 0-byte file: $OutFile"
  }
  if (-not (Test-ZipArchive -Path $OutFile)) {
    throw "$Name download is not a valid zip archive: $OutFile"
  }
}

function Resolve-JdkHome {
  param([string]$Root)

  if (Test-Path -LiteralPath (Join-Path $Root 'bin\jlink.exe')) {
    return $Root
  }

  $NestedJdk = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\jlink.exe') } |
    Select-Object -First 1

  if ($NestedJdk) {
    return $NestedJdk.FullName
  }

  return $null
}

function Write-UseEnvScript {
  $UseScriptPath = Join-Path $ScriptsDir 'use_flutter_android_env.ps1'
  $Content = @"
`$env:FLUTTER_HOME = '$FlutterHome'
`$env:ANDROID_HOME = '$AndroidSdk'
`$env:ANDROID_SDK_ROOT = '$AndroidSdk'
`$env:JAVA_HOME = '$JdkHome'
`$env:GRADLE_USER_HOME = '$GradleUserHome'
`$env:FLUTTER_STORAGE_BASE_URL = '$FlutterStorageBaseUrl'
`$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
`$env:Path = "`$env:FLUTTER_HOME\bin;`$env:JAVA_HOME\bin;`$env:ANDROID_HOME\platform-tools;`$env:ANDROID_HOME\cmdline-tools\latest\bin;`$env:Path"

Write-Host 'Flutter Android environment loaded for this PowerShell session.'
Write-Host "Flutter: `$env:FLUTTER_HOME"
Write-Host "Android SDK: `$env:ANDROID_HOME"
Write-Host "JDK: `$env:JAVA_HOME"
Write-Host "Gradle cache: `$env:GRADLE_USER_HOME"
"@

  Set-Content -LiteralPath $UseScriptPath -Value $Content -Encoding UTF8
  Write-Host "Environment script written: $UseScriptPath"
}

Ensure-Directory $InstallRoot
Ensure-Directory $DownloadsDir
Ensure-Directory $AndroidSdk
Ensure-Directory (Join-Path $AndroidSdk 'cmdline-tools')
Ensure-Directory $GradleUserHome
Ensure-Directory $ScriptsDir

if (-not (Test-Path -LiteralPath (Join-Path $FlutterHome 'bin\flutter.bat'))) {
  Download-FileIfMissing -Url $FlutterUrl -OutFile $FlutterZip -Name 'Flutter SDK'
  Write-Host 'Extracting Flutter SDK...'
  Expand-Archive -LiteralPath $FlutterZip -DestinationPath $InstallRoot
}
else {
  Write-Host "Flutter SDK already installed: $FlutterHome"
}

$AndroidToolsHome = Join-Path $AndroidSdk 'cmdline-tools\latest'
if (-not (Test-Path -LiteralPath (Join-Path $AndroidToolsHome 'bin\sdkmanager.bat'))) {
  Download-FileIfMissing -Url $AndroidToolsUrl -OutFile $AndroidToolsZip -Name 'Android command-line tools'
  $AndroidExtractDir = Join-Path $InstallRoot 'android_cmdline_tools_extract'
  if (Test-Path -LiteralPath $AndroidExtractDir) {
    throw "Temporary folder already exists: $AndroidExtractDir. Please inspect it before rerunning."
  }

  Write-Host 'Extracting Android command-line tools...'
  Expand-Archive -LiteralPath $AndroidToolsZip -DestinationPath $AndroidExtractDir
  Move-Item -LiteralPath (Join-Path $AndroidExtractDir 'cmdline-tools') -Destination $AndroidToolsHome
}
else {
  Write-Host "Android command-line tools already installed: $AndroidToolsHome"
}

$ResolvedJdkHome = Resolve-JdkHome -Root $JdkRoot
if (-not $ResolvedJdkHome) {
  if (Test-Path -LiteralPath (Join-Path $BundledJdkCandidate 'bin\jlink.exe')) {
    Write-Host "Copying existing full JDK 17 from: $BundledJdkCandidate"
    Copy-Item -LiteralPath $BundledJdkCandidate -Destination $JdkRoot -Recurse
  }
  else {
    Download-FileIfMissing -Url $JdkUrl -OutFile $JdkZip -Name 'Microsoft JDK 17'
    $JdkExtractDir = Join-Path $InstallRoot 'jdk17_full_extract'
    if (Test-Path -LiteralPath $JdkExtractDir) {
      throw "Temporary folder already exists: $JdkExtractDir. Please inspect it before rerunning."
    }

    Write-Host 'Extracting Microsoft JDK 17...'
    Expand-Archive -LiteralPath $JdkZip -DestinationPath $JdkExtractDir
    $ExtractedJdk = Get-ChildItem -LiteralPath $JdkExtractDir -Directory | Select-Object -First 1
    if (-not $ExtractedJdk) {
      throw 'Could not find extracted JDK folder.'
    }
    Move-Item -LiteralPath $ExtractedJdk.FullName -Destination $JdkRoot
  }
  $ResolvedJdkHome = Resolve-JdkHome -Root $JdkRoot
}
else {
  Write-Host "Full JDK 17 already installed: $ResolvedJdkHome"
}

if (-not $ResolvedJdkHome) {
  throw "Could not find a full JDK with bin\jlink.exe under $JdkRoot."
}

$JdkHome = $ResolvedJdkHome

Write-UseEnvScript
. (Join-Path $ScriptsDir 'use_flutter_android_env.ps1')
$env:FLUTTER_STORAGE_BASE_URL = $FlutterStorageBaseUrl
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'

Write-Host 'Accepting Android SDK licenses for this local SDK...'
1..20 | ForEach-Object { 'y' } | & (Join-Path $AndroidToolsHome 'bin\sdkmanager.bat') --licenses

Write-Host 'Installing Android SDK packages...'
& (Join-Path $AndroidToolsHome 'bin\sdkmanager.bat') `
  'platform-tools' `
  'platforms;android-36' `
  'build-tools;36.0.0'

Write-Host 'Configuring Flutter Android SDK path...'
& (Join-Path $FlutterHome 'bin\flutter.bat') config --android-sdk $AndroidSdk

Write-Host 'Preparing Flutter Android artifacts...'
& (Join-Path $FlutterHome 'bin\flutter.bat') precache --android

Write-Host 'Running Flutter doctor...'
& (Join-Path $FlutterHome 'bin\flutter.bat') doctor -v

Write-Host 'Install finished.'
