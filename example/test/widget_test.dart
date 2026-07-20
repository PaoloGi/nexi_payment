import 'package:flutter_test/flutter_test.dart';

import 'package:nexi_payment_example/main.dart';

void main() {
  testWidgets('renders the payment buttons', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.text('PAY'), findsOneWidget);
    expect(find.text('PAY WITH NPG (HPP)'), findsOneWidget);
  });
}
