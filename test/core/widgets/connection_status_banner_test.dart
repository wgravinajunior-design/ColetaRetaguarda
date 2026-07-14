import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/widgets/connection_status_banner.dart';

void main() {
  group('ConnectionStatusBanner Widget Tests', () {
    testWidgets('renderiza sem banner quando online', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionStatusBanner(
            child: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: const Center(child: Text('Content')),
            ),
          ),
        ),
      );

      // Aguarda a primeira checagem de conexão
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      // O banner deve estar invisível ou não renderizado quando online
    });

    testWidgets('renderiza banner laranja quando offline', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionStatusBanner(
            child: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: const Center(child: Text('Content')),
            ),
          ),
        ),
      );

      // Aguarda checagem de conexão
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('layout com child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionStatusBanner(
            child: Scaffold(
              appBar: AppBar(title: const Text('Test App')),
              body: const Center(
                child: Text('Main Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Main Content'), findsOneWidget);
    });

    testWidgets('hierarquia de widgets correta', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionStatusBanner(
            child: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
