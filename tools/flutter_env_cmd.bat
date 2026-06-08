@echo off
set "INSTALL_ROOT=D:\Flutter_Android_Huanjing"
set "FLUTTER_HOME=%INSTALL_ROOT%\flutter"
set "ANDROID_HOME=%INSTALL_ROOT%\android_sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "GRADLE_USER_HOME=%INSTALL_ROOT%\gradle_home"
set "JAVA_HOME=%INSTALL_ROOT%\jdk17_full"

if not exist "%JAVA_HOME%\bin\jlink.exe" (
  for /d %%J in ("%JAVA_HOME%\*") do (
    if exist "%%J\bin\jlink.exe" set "JAVA_HOME=%%J"
  )
)

set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "PATH=%FLUTTER_HOME%\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;%PATH%"

cd /d D:\Desktop\phone

echo Flutter Android environment loaded.
echo Flutter: %FLUTTER_HOME%
echo Android SDK: %ANDROID_HOME%
echo JDK: %JAVA_HOME%
echo Gradle cache: %GRADLE_USER_HOME%
echo.
cmd /k
