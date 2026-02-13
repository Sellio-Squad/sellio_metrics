import 'package:flutter_test/flutter_test.dart';
import 'package:sellio_metrics/app.dart';

void main() {
  testWidgets('App renders loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SellioMetricsApp());
    expect(find.text('Loading team metrics...'), findsOneWidget);
  });
}
