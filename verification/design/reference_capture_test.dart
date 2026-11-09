import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'approved_reference.dart';

void main() {
  testWidgets('Capture the approved implementation', (tester) async {
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold', 'black']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Roboto-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    for (final width in [390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const CASLMSPreviewApp()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('verification/design/reference-${width.toInt()}.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
