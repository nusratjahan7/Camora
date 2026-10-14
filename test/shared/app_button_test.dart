import 'package:camera_overlay/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton renders its label and reports taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Capture', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Capture'), findsOneWidget);

    await tester.tap(find.text('Capture'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
