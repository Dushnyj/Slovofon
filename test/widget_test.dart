import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';

void main() {
  testWidgets('renders Slovofon app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SlovofonApp()));
    await tester.pumpAndSettle();

    expect(find.text('Find a book in Izib'), findsOneWidget);
    expect(find.text('Open search'), findsOneWidget);
  });
}
