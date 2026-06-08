import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../features/home/presentation/home_page.dart';
import 'theme/app_theme.dart';

class FileConverterApp extends StatelessWidget {
  const FileConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
