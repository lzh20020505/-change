import 'package:flutter/material.dart';

class ConversionFeature {
  const ConversionFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.pageBuilder,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final WidgetBuilder pageBuilder;
}
