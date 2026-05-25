import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';

void main() {
  testWidgets('renders Slovofon app shell', (tester) async {
    await tester.pumpWidget(const SlovofonApp());
    await tester.pumpAndSettle();

    expect(find.text('Continue listening'), findsOneWidget);
  });
}
