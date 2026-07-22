import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexi_payment_example/main.dart';
import 'package:nexi_payment_example/payment_result_dialog.dart';

void main() {
  testWidgets('renders the payment buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('PAY'), findsOneWidget);
    expect(find.text('PAY WITH NPG (HPP)'), findsOneWidget);
  });

  // The home screen and the result dialog must lay out without a RenderFlex
  // overflow on any screen — a debug overflow throws and would fail the Patrol
  // integration tests (which pumpWidgetAndSettle the example app) on small
  // devices. These pump the app at extreme surface sizes; the framework raises
  // an exception on overflow, so reaching the assertions means it laid out.
  final sizes = <String, Size>{
    'tiny phone (320x480)': const Size(320, 480),
    'short split-screen (400x300)': const Size(400, 300),
    'tablet (1600x2560)': const Size(1600, 2560),
  };

  sizes.forEach((label, size) {
    testWidgets('home screen lays out without overflow on $label', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Buttons are always in the tree; on a short screen they scroll rather
      // than overflow.
      expect(find.text('PAY'), findsOneWidget);
      expect(find.text('PAY WITH NPG (HPP)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'result dialog with a long message does not overflow on a tiny screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPaymentResultDialog(
                    context,
                    PaymentResultKind.error,
                    detail: 'RESULT_PARSING_FAILED — ${'lorem ipsum ' * 60}',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
