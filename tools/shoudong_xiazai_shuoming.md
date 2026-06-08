# 手动下载说明

正常情况下 Gradle 会从 Maven Central 自动下载。若联网构建失败，请创建：

```text
D:\QingZhuan_GouJian_HuanCun\ShouDong_XiaZai
```

将下面 3 个文件原名放入该目录：

1. `ffmpeg-kit-audio-6.0.1.aar`

   <https://repo1.maven.org/maven2/io/github/maxrave-dev/ffmpeg-kit-audio/6.0.1/ffmpeg-kit-audio-6.0.1.aar>

2. `smart-exception-java-0.2.1.jar`

   <https://repo1.maven.org/maven2/com/arthenica/smart-exception-java/0.2.1/smart-exception-java-0.2.1.jar>

3. `smart-exception-common-0.2.1.jar`

   <https://repo1.maven.org/maven2/com/arthenica/smart-exception-common/0.2.1/smart-exception-common-0.2.1.jar>

`android/app/build.gradle.kts` 会优先检查这 3 个文件；全部存在时使用手动文件，
否则使用 Maven Central 坐标。

然后在 PowerShell 中运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_qingzhuan_android.ps1
```

构建缓存统一保存在：

```text
D:\QingZhuan_GouJian_HuanCun
```
