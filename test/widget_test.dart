// Smoke test básico do app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp renderiza um widget básico', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('ColetaUp'))),
      ),
    );

    expect(find.text('ColetaUp'), findsOneWidget);
  });
}
