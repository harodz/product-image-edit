// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:product_image_edit_frontend/main.dart';
import 'package:product_image_edit_frontend/services/pipeline_runner.dart';

void main() {
  testWidgets('App boots and shows nav', (WidgetTester tester) async {
    final tmp = Directory.systemTemp.createTempSync('pie_test');
    addTearDown(() {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    });
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final runner = PipelineRunner()..setApplicationSupportDirectory(tmp.path);
    await tester.pumpWidget(
      ProductImageEditApp(
        runner: runner,
        applicationSupportPath: tmp.path,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('产品'), findsWidgets);
    expect(find.text('流水线设置'), findsWidgets);
  });
}
