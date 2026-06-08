import 'package:flutter/material.dart';

import '../../../core/models/conversion_feature.dart';
import '../../history/presentation/history_page.dart';
import '../../image_compress/presentation/image_compress_page.dart';
import '../../image_convert/presentation/image_convert_page.dart';
import '../../image_to_pdf/presentation/image_to_pdf_page.dart';
import '../../video_extract_audio/presentation/video_extract_audio_page.dart';

final conversionFeatures = <ConversionFeature>[
  ConversionFeature(
    title: '图片转换',
    description: 'JPG、PNG、WebP 等格式互转',
    icon: Icons.image_outlined,
    color: const Color(0xFF2563EB),
    pageBuilder: (_) => const ImageConvertPage(),
  ),
  ConversionFeature(
    title: '图片压缩',
    description: '调整质量和尺寸，减少文件体积',
    icon: Icons.photo_size_select_small_outlined,
    color: const Color(0xFF059669),
    pageBuilder: (_) => const ImageCompressPage(),
  ),
  ConversionFeature(
    title: '图片转 PDF',
    description: '多张图片合并生成 PDF 文件',
    icon: Icons.picture_as_pdf_outlined,
    color: const Color(0xFFDC2626),
    pageBuilder: (_) => const ImageToPdfPage(),
  ),
  ConversionFeature(
    title: '视频提取音频',
    description: '从视频中导出音频文件',
    icon: Icons.audiotrack_outlined,
    color: const Color(0xFF7C3AED),
    pageBuilder: (_) => const VideoExtractAudioPage(),
  ),
  ConversionFeature(
    title: '转换记录',
    description: '查看最近处理过的文件',
    icon: Icons.history_rounded,
    color: const Color(0xFFEA580C),
    pageBuilder: (_) => const HistoryPage(),
  ),
];
