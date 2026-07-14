import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/financeiro/models/movimento_model.dart';

void main() {
  group('MovimentoModel', () {
    test('creates movimento with required fields', () {
      final movimento = MovimentoModel(
        id: 1,
        tipo: 'C',
        valor: 1500.0,
        dtEmissao: '2026-01-01',
        historico: 'Venda',
      );

      expect(movimento.id, 1);
      expect(movimento.tipo, 'C');
      expect(movimento.valor, 1500.0);
      expect(movimento.historico, 'Venda');
    });

    test('movimento tipo C is receita', () {
      final movimento = MovimentoModel(
        id: 1,
        tipo: 'C',
        valor: 100.0,
        dtEmissao: '2026-01-01',
        historico: 'Receita',
      );

      expect(movimento.tipo, 'C');
    });

    test('movimento tipo D is despesa', () {
      final movimento = MovimentoModel(
        id: 2,
        tipo: 'D',
        valor: 50.0,
        dtEmissao: '2026-01-02',
        historico: 'Despesa',
      );

      expect(movimento.tipo, 'D');
    });

    test('toJson serializes movimento correctly', () {
      final movimento = MovimentoModel(
        id: 1,
        tipo: 'C',
        valor: 1000.0,
        conta: 1,
        dtEmissao: '2026-01-01',
        historico: 'Venda',
        status: 'C',
      );

      final json = movimento.toJson();
      expect(json['mov_tipo'], 'C');
      expect(json['mov_valor'], 1000.0);
      expect(json['mov_historico'], 'Venda');
    });

    test('fromJson deserializes movimento correctly', () {
      final json = {
        'mov_id': 1,
        'mov_tipo': 'D',
        'mov_valor': 500.0,
        'mov_dt_emissao': '2026-01-01',
        'mov_historico': 'Frete',
      };

      final movimento = MovimentoModel.fromJson(json);
      expect(movimento.tipo, 'D');
      expect(movimento.valor, 500.0);
    });

    test('movimento status C is compensado', () {
      final movimento = MovimentoModel(
        id: 1,
        tipo: 'C',
        valor: 100.0,
        dtEmissao: '2026-01-01',
        historico: 'Receita',
        status: 'C',
      );

      expect(movimento.status, 'C');
    });

    test('movimento status P is pendente', () {
      final movimento = MovimentoModel(
        id: 2,
        tipo: 'D',
        valor: 50.0,
        dtEmissao: '2026-01-02',
        historico: 'Despesa',
        status: 'P',
      );

      expect(movimento.status, 'P');
    });

    test('movimento with conta field stores account', () {
      final movimento = MovimentoModel(
        id: 1,
        tipo: 'C',
        valor: 1000.0,
        conta: 123,
        contaNome: 'Banco do Brasil',
        dtEmissao: '2026-01-01',
        historico: 'Venda',
      );

      expect(movimento.conta, 123);
      expect(movimento.contaNome, 'Banco do Brasil');
    });
  });
}
