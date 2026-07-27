import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/ui/rolagem.dart';

/// Monta um app com o comportamento de rolagem do sistema e devolve a barra
/// que o Flutter inseriu sozinho em volta do [filho].
Future<Scrollbar> barraDe(WidgetTester tester, Widget filho) async {
  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: const RolagemSempreVisivel(),
      home: Scaffold(body: filho),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<Scrollbar>(find.byType(Scrollbar).first);
}

void main() {
  testWidgets('lista comprida ganha barra fixa, sem precisar pedir', (
    tester,
  ) async {
    final barra = await barraDe(
      tester,
      ListView(
        children: List.generate(80, (i) => ListTile(title: Text('item $i'))),
      ),
    );

    expect(barra.thumbVisibility, isTrue, reason: 'a barra deve ficar à vista');
    expect(barra.trackVisibility, isTrue, reason: 'a trilha deve aparecer');
    expect(barra.interactive, isTrue, reason: 'deve dar para arrastar a barra');
  });

  testWidgets('formulário longo também ganha barra fixa', (tester) async {
    final barra = await barraDe(
      tester,
      SingleChildScrollView(
        child: Column(
          children: List.generate(60, (i) => SizedBox(height: 40, child: Text('campo $i'))),
        ),
      ),
    );
    expect(barra.thumbVisibility, isTrue);
  });

  testWidgets('tabela larga: rolagem horizontal não estoura', (tester) async {
    // Vertical por fora, horizontal por dentro — o desenho das telas de
    // relatório. O de dentro não é "primary", então não tem controlador
    // próprio: a barra precisa cair no modo normal em vez de falhar.
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const RolagemSempreVisivel(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 3000, height: 3000),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Uma barra para cada eixo.
    expect(find.byType(Scrollbar), findsNWidgets(2));
  });

  testWidgets('o mouse pode arrastar o conteúdo, e não só a roda', (
    tester,
  ) async {
    const comportamento = RolagemSempreVisivel();
    expect(comportamento.dragDevices, contains(PointerDeviceKind.mouse));
  });
}
