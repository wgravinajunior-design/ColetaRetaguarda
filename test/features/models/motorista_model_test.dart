import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/motoristas/models/motorista_model.dart';

void main() {
  group('MotoristaModel', () {
    test('creates motorista with all fields', () {
      final motorista = MotoristaModel(
        id: 1,
        nome: 'João Silva',
        apelido: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        telefone: '(31) 3333-4444',
        celular: '(31) 99999-8888',
        email: 'joao@example.com',
        endereco: 'Rua A',
        numero: '100',
        complemento: 'Apt 10',
        bairro: 'Bairro Centro',
        cidade: 'Belo Horizonte',
        cep: '30130-100',
        cnh: '123456789',
        cnhValidade: '2030-12-31',
        status: 'A',
      );

      expect(motorista.id, 1);
      expect(motorista.nome, 'João Silva');
      expect(motorista.cpf, '123.456.789-00');
      expect(motorista.status, 'A');
    });

    test('toJson serializes motorista correctly', () {
      final motorista = MotoristaModel(
        id: 1,
        nome: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        status: 'A',
      );

      final json = motorista.toJson();
      expect(json['nome'], 'João');
      expect(json['cpf'], '123.456.789-00');
    });

    test('fromJson deserializes motorista correctly', () {
      final json = {
        'id': 1,
        'nome': 'João',
        'cpf': '123.456.789-00',
        'rg': 'MG-1234567',
        'status': 'A',
      };

      final motorista = MotoristaModel.fromJson(json);
      expect(motorista.id, 1);
      expect(motorista.nome, 'João');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = MotoristaModel(
        id: 1,
        nome: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        status: 'A',
      );

      final updated = original.copyWith(nome: 'João Silva');
      expect(updated.nome, 'João Silva');
      expect(updated.id, 1);
      expect(original.nome, 'João'); // Original unchanged
    });

    test('motorista with status A is active', () {
      final motorista = MotoristaModel(
        id: 1,
        nome: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        status: 'A',
      );

      expect(motorista.status, 'A');
    });

    test('motorista with status I is inactive', () {
      final motorista = MotoristaModel(
        id: 1,
        nome: 'João',
        cpf: '123.456.789-00',
        rg: 'MG-1234567',
        status: 'I',
      );

      expect(motorista.status, 'I');
    });
  });
}
