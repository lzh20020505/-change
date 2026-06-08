$InstallRoot = 'D:\Flutter_Android_Huanjing'

$env:FLUTTER_HOME = Join-Path $InstallRoot 'flutter'
$env:ANDROID_HOME = Join-Path $InstallRoot 'android_sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$JdkRoot = Join-Path $InstallRoot 'jdk17_full'
if (Test-Path -LiteralPath (Join-Path $JdkRoot 'bin\jlink.exe')) {
  $env:JAVA_HOME = $JdkRoot
}
else {
  $NestedJdk = Get-ChildItem -LiteralPath $JdkRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\jlink.exe') } |
    Select-Object -First 1

  if (-not $NestedJdk) {
    throw "Could not find a full JDK with bin\jlink.exe under $JdkRoot."
  }

  $env:JAVA_HOME = $NestedJdk.FullName
}
$env:GRADLE_USER_HOME = Join-Path $InstallRoot 'gradle_home'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:Path = "$env:FLUTTER_HOME\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:Path"

Write-Host 'Flutter Android environment loaded for this PowerShell session.'
Write-Host "Flutter: $env:FLUTTER_HOME"
Write-Host "Android SDK: $env:ANDROID_HOME"
Write-Host "JDK: $env:JAVA_HOME"
Write-Host "Gradle cache: $env:GRADLE_USER_HOME"
