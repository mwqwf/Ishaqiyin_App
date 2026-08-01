import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menbaradkshk/widgets/skeleton_loader.dart';

void main() {
  testWidgets('HomeSkeleton fits a narrow phone without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HomeSkeleton()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
