import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/veiculos/models/veiculo_model.dart';

void main() {
  group('VeiculoModel', () {
    test('creates veiculo with all fields', () {
      final veiculo = VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        modelo: 'Sprinter',
        cor: 'Branco',
        ano: '2022',
        tipo: 'F',
        renavam: '12345678901234',
        chassi: 'WVWZZZ3CZ6E123456',
        status: 'A',
      );

      expect(veiculo.id, 1);
      expect(veiculo.placa, 'ABC-1234');
      expect(veiculo.marca, 'Mercedes');
      expect(veiculo.status, 'A');
    });

    test('toJson serializes veiculo correctly', () {
      final veiculo = VeiculoModel(
        id: 1,
        placa: 'XYZ-5678',
        marca: 'Volvo',
        modelo: 'FH',
        status: 'A',
      );

      final json = veiculo.toJson();
      expect(json['placa'], 'XYZ-5678');
      expect(json['marca'], 'Volvo');
    });

    test('fromJson deserializes veiculo correctly', () {
      final json = {
        'id': 1,
        'placa': 'ABC-1234',
        'marca': 'Mercedes',
        'modelo': 'Sprinter',
        'status': 'A',
      };

      final veiculo = VeiculoModel.fromJson(json);
      expect(veiculo.placa, 'ABC-1234');
    });

    test('veiculo tipo F is Frete', () {
      final veiculo = VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        tipo: 'F',
        status: 'A',
      );

      expect(veiculo.tipo, 'F');
    });

    test('veiculo tipo C is Coleta', () {
      final veiculo = VeiculoModel(
        id: 2,
        placa: 'XYZ-5678',
        marca: 'Volvo',
        tipo: 'C',
        status: 'A',
      );

      expect(veiculo.tipo, 'C');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        status: 'A',
      );

      final updated = original.copyWith(status: 'I');
      expect(updated.status, 'I');
      expect(updated.placa, 'ABC-1234');
      expect(original.status, 'A');
    });
  });
}
