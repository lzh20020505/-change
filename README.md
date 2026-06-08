# lzhᴗh

项目开发复盘见 [从 lzhᴗh 开始学习移动端开发](docs/vibe-coding-flutter-android-retrospective.md)。

项目内沉淀的 Codex Skill 见 [.codex/skills/build-lightweight-flutter-android](.codex/skills/build-lightweight-flutter-android/SKILL.md)。

一个面向 Android 手机自用的轻量本地文件转换工具。

## 当前阶段

- 图片转换
- 图片压缩
- 图片转 PDF
- 视频提取音频
- 转换记录
- 本地文件选择
- 输出目录管理
- Android 原生图片格式转换（JPG、PNG、WebP）
- Android 原生批量图片压缩（质量与尺寸设置）
- Android 原生多图片转 PDF

## 第三阶段

当前已开始接入真实文件处理：

- 图片转换、图片压缩和图片转 PDF 通过 MethodChannel 调用 Android 原生 API。
- 处理任务在单独线程执行，图片写入 `LiteConverter/Images`，PDF 写入 `LiteConverter/Pdfs`。
- 输出文件自动使用递增后缀，避免覆盖已有文件。
- 图片方向会按常见 EXIF 旋转信息修正。
- 压缩结果统一输出 JPG，透明区域使用白色背景。
- PDF 支持 A4、Letter、原图比例、横竖方向、完整适配和填满裁剪。
- PDF 图片列表支持分批添加、上移、下移、移除和清空。

后续按顺序实现转换记录持久化、输出文件打开/分享，以及视频音频处理。

## 第四阶段

- 使用 `LiteConverter/conversion_history.json` 保存转换记录，不引入数据库依赖。
- 最多保留最近 200 条记录；单条坏记录会跳过，整体 JSON 损坏时会备份为
  `conversion_history.json.corrupt` 后自动恢复为空记录。
- 图片转换、图片压缩和图片转 PDF 完成后自动写入记录。
- 转换结果页和记录页均支持打开、分享和删除结果文件。
- 打开与分享使用 Android 原生 `Intent` 和只读 `FileProvider` URI，不新增 Flutter 插件。
- “发送原文件”使用通用文件 MIME，避免聊天软件按普通图片重新压缩；聊天软件的
  “保存图片到相册”仍可能自行重新编码。
- `FileProvider` 仅授权 `LiteConverter` 输出目录，兼容 Android 上
  `app_flutter/LiteConverter` 的实际文档路径。
- 删除文件时同步删除对应记录；文件已被外部删除时，记录页会标记并允许清理失效记录。

## 第五阶段

- 视频提取音频已接入 Android 原生通道和 LGPL FFmpegKit。
- 支持 MP3、M4A 和 WAV；MP3/M4A 可选 128、192、320 kbps，WAV
  可选 44100、48000 Hz。
- 处理固定使用单线程，只映射第一条音频流，不解码视频画面。
- 支持实时进度、取消、异常提示和半成品清理。
- 超过 1 GB 的文件会二次确认，超过 4 GB 或 12 小时的文件会拒绝处理。
- 开始处理前会按音频参数估算输出空间并预留 16 MB 安全余量。
- Android 安装包仅包含 `arm64-v8a` 和 `armeabi-v7a`，不打包模拟器 ABI。
- 构建脚本按 ABI 分别生成 ARM64 和 ARM32 APK，避免一个安装包同时携带两套原生库。
- 合并清单显式移除 FFmpeg 依赖声明的联网权限，音频处理保持完全离线。
- Debug APK 为支持真机热重载仍包含 Flutter 开发联网权限；日常安装使用的 Release APK
  不包含联网权限。

许可证及发布注意事项见 `THIRD_PARTY_NOTICES.md`。当前 FFmpegKit 来源是社区重建包，
正式对外分发前必须再次核对 AAR 的实际编译参数和 LGPL 合规材料。

## 第六阶段

- 首页显示当前长任务、总记录数和音频记录数。
- 历史筛选显示各类型记录数量。
- 应用名称更新为 `lzhᴗh`，版本更新为 `0.3.0+4`，并增加应用信息页。
- Android 启动图标更新为轻量矢量“文件转换”图标。
- 原尺寸图片处理限制为 2400 万像素，降低低内存设备发生 OOM 的风险。

为适配内存较小的开发电脑，Android Gradle 最大堆已设置为 3 GB。建议优先连接 Android 真机调试，不需要安装模拟器。

## 本机需要安装的环境

1. Flutter SDK stable 版，安装后把 `flutter\bin` 加入 `PATH`。
2. Android Studio，用于安装 Android SDK、模拟器和调试工具。
3. Android SDK Platform、Android SDK Command-line Tools、Android SDK Build-Tools、Android SDK Platform-Tools。
4. Git for Windows。
5. VS Code 或 Android Studio Flutter 插件，二选一即可。
6. 真机调试时需要开启 Android 手机的开发者选项和 USB 调试，Windows 可能还需要手机厂商 USB 驱动。

安装后建议运行：

```powershell
flutter doctor
flutter doctor --android-licenses
flutter pub get
```

官方参考：

- [Flutter Windows + Android 安装文档](https://docs.flutter.dev/get-started/install/windows/mobile)
- [Flutter Android 平台配置](https://docs.flutter.dev/platform-integration/android/setup)

当前目录是在没有 Flutter SDK 的环境里创建的。安装 Flutter 后，如果需要生成 Android 原生平台目录，请在项目根目录执行：

```powershell
flutter create --platforms=android .
```

## Flutter 依赖

当前已接入：

- `file_picker`：选择本地文件
- `path_provider`：获取应用文档目录
- `permission_handler`：权限能力扩展点
- `cupertino_icons`：基础图标

后续实现本地转换时，可按模块逐步引入：

- 图片压缩：`flutter_image_compress` 或基于 Dart `image` 包处理
- 图片转 PDF：`pdf`
- 打开/分享文件：`open_filex`、`share_plus`
- 转换记录：`sqflite`、`drift` 或 `isar`
- 视频提取音频：FFmpeg 相关 Flutter 插件，需重点确认 Android 兼容性和 LGPL/GPL 许可

## 项目结构

```text
lib/
  app/
    app.dart
    theme/
      app_theme.dart
  core/
    models/
      conversion_feature.dart
      selected_file_info.dart
    services/
      file_picker_service.dart
      output_directory_service.dart
      permission_service.dart
  features/
    home/
      data/
        conversion_features.dart
      presentation/
        home_page.dart
        widgets/
          feature_card.dart
    image_convert/
    image_compress/
    image_to_pdf/
    video_extract_audio/
    history/
  shared/
    widgets/
      feature_placeholder_page.dart
```

## 输出目录

应用会在 Documents 下创建统一输出目录：

```text
Documents/
  LiteConverter/
    Images/
    Pdfs/
    Audio/
    Temp/
```

在 Android 上，这里的 Documents 指应用可访问的文档目录；如果后续需要写入手机公共 Documents 目录，需要再接入系统文件访问框架或媒体库写入能力。

## 运行

```powershell
flutter pub get
flutter run
```
