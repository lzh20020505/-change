import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_file_converter/app/app.dart';

void main() {
  testWidgets('home page shows conversion modules', (tester) async {
    await tester.pumpWidget(const FileConverterApp());

    expect(find.text('lzhᴗh'), findsOneWidget);
    expect(find.text('图片转换'), findsOneWidget);
    expect(find.text('图片压缩'), findsOneWidget);
    expect(find.text('图片转 PDF'), findsOneWidget);
    expect(find.text('视频提取音频'), findsOneWidget);
    expect(find.text('转换记录'), findsOneWidget);
  });

  testWidgets('module card opens tool page scaffold', (tester) async {
    await tester.pumpWidget(const FileConverterApp());

    await tester.tap(find.text('图片转换'));
    await tester.pumpAndSettle();

    expect(find.text('输入文件'), findsOneWidget);
    expect(find.text('转换设置'), findsOneWidget);
    expect(find.text('开始转换'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
  });
}
