import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/produtores/models/pessoa_model.dart';

void main() {
  group('PessoaModel', () {
    test('creates pessoa with required fields', () {
      final pessoa = PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'João da Silva',
        cnpjCpf: '123.456.789-00',
        status: 'A',
        cliente: 'S',
      );

      expect(pessoa.id, 1);
      expect(pessoa.tipoPessoa, 'P');
      expect(pessoa.rSocialNome, 'João da Silva');
      expect(pessoa.status, 'A');
    });

    test('toJson serializes pessoa correctly', () {
      final pessoa = PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'Produtor A',
        cnpjCpf: '123.456.789-00',
        status: 'A',
        cliente: 'S',
      );

      final json = pessoa.toJson();
      expect(json['rSocialNome'], 'Produtor A');
      expect(json['cnpjCpf'], '123.456.789-00');
      expect(json['cliente'], 'S');
    });

    test('fromJson deserializes pessoa correctly', () {
      final json = {
        'id': 1,
        'tipo_pessoa': 'P',
        'rsocial_nome': 'Produtor B',
        'cnpj_cpf': '987.654.321-00',
        'status': 'A',
        'cliente': 'S',
        'transportador': 'N',
        'contribuinte': 'S',
      };

      final pessoa = PessoaModel.fromJson(json);
      expect(pessoa.id, 1);
      expect(pessoa.tipoPessoa, 'P');
    });

    test('pessoa can be produtor', () {
      final pessoa = PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'Produtor',
        cnpjCpf: '123.456.789-00',
        status: 'A',
        cliente: 'S',
      );

      expect(pessoa.tipoPessoa, 'P');
    });

    test('pessoa can be transportador', () {
      final pessoa = PessoaModel(
        id: 2,
        tipoPessoa: 'T',
        rSocialNome: 'Transportadora',
        cnpjCpf: '111.222.333-44',
        status: 'A',
        transportador: 'S',
      );

      expect(pessoa.transportador, 'S');
    });

    test('pessoa can be colaborador', () {
      final pessoa = PessoaModel(
        id: 3,
        tipoPessoa: 'C',
        rSocialNome: 'Colaborador',
        cnpjCpf: '555.666.777-88',
        status: 'A',
        cliente: 'N',
      );

      expect(pessoa.tipoPessoa, 'C');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'Original',
        cnpjCpf: '123.456.789-00',
        status: 'A',
        cliente: 'S',
      );

      final updated = original.copyWith(rSocialNome: 'Updated');
      expect(updated.rSocialNome, 'Updated');
      expect(updated.id, 1);
      expect(original.rSocialNome, 'Original');
    });
  });
}
