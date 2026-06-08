import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../shared/widgets/tool_page.dart';

class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolPage(
      title: '关于 lzhᴗh',
      description: '本地优先、轻量自用的 Android 文件转换工具。',
      icon: Icons.info_outline_rounded,
      color: Color(0xFF475569),
      children: [
        ToolSection(
          title: '版本信息',
          icon: Icons.apps_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppInfo.name} ${AppInfo.version}'),
              SizedBox(height: 6),
              Text('构建号 ${AppInfo.buildNumber}'),
              SizedBox(height: 6),
              Text('所有转换均在设备本地完成。'),
            ],
          ),
        ),
        ToolSection(
          title: '第三方组件',
          icon: Icons.article_outlined,
          child: Text(
            '视频提取音频使用 LGPL 版 FFmpegKit。发布安装包前应随包提供对应许可证和第三方声明。',
          ),
        ),
      ],
    );
  }
}
