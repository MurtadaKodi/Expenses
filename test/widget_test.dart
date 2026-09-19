import 'package:expenses/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Expenses app loads months grid', (WidgetTester tester) async {
    // Build app with a test store and trigger a frame.
    await tester.pumpWidget(ExpensesApp(store: ExpensesStore.memory()));

    // Verify key UI content exists.
    expect(find.text('المصروفات - الشهور'), findsOneWidget);
    expect(find.text('يناير'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
  });
}
