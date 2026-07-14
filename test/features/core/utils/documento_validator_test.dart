import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/features/core/utils/documento_validator.dart';

void main() {
  group('DocumentoValidator', () {
    test('valida CPF correto', () {
      expect(DocumentoValidator.validarCpf('529.982.247-25'), true);
      expect(DocumentoValidator.validarCpf('52998224725'), true);
    });

    test('rejeita CPF inválido', () {
      expect(DocumentoValidator.validarCpf('111.111.111-11'), false);
      expect(DocumentoValidator.validarCpf('123.456.789-00'), false);
      expect(DocumentoValidator.validarCpf('123'), false);
    });

    test('valida CNPJ correto', () {
      expect(DocumentoValidator.validarCnpj('11.222.333/0001-81'), true);
      expect(DocumentoValidator.validarCnpj('11222333000181'), true);
    });

    test('rejeita CNPJ inválido', () {
      expect(DocumentoValidator.validarCnpj('11.222.333/0001-00'), false);
      expect(DocumentoValidator.validarCnpj('00.000.000/0000-00'), false);
    });

    test('validar detecta CPF ou CNPJ pelo tamanho', () {
      expect(DocumentoValidator.validar('52998224725'), true);
      expect(DocumentoValidator.validar('11222333000181'), true);
      expect(DocumentoValidator.validar('12345'), false);
    });

    test('mensagemErro retorna null para válido e vazio não-obrigatório', () {
      expect(DocumentoValidator.mensagemErro('529.982.247-25'), null);
      expect(DocumentoValidator.mensagemErro(''), null);
      expect(DocumentoValidator.mensagemErro('', obrigatorio: true), isNotNull);
      expect(DocumentoValidator.mensagemErro('111.111.111-11'), 'CPF inválido');
    });

    test('formata CPF e CNPJ', () {
      expect(DocumentoValidator.formatar('52998224725'), '529.982.247-25');
      expect(DocumentoValidator.formatar('11222333000181'), '11.222.333/0001-81');
    });
  });
}
