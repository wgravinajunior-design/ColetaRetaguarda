import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/validation/validators.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('retorna erro se vazio', () {
        expect(Validators.required(''), isNotNull);
        expect(Validators.required(null), isNotNull);
      });

      test('retorna null se preenchido', () {
        expect(Validators.required('valor'), isNull);
      });

      test('usa label customizado na mensagem', () {
        final error = Validators.required('', label: 'Email');
        expect(error, contains('Email'));
      });
    });

    group('email', () {
      test('valida emails corretos', () {
        expect(Validators.email('test@example.com'), isNull);
        expect(Validators.email('user.name@domain.co.uk'), isNull);
      });

      test('rejeita emails inválidos', () {
        expect(Validators.email('invalid.email'), isNotNull);
        expect(Validators.email('test@'), isNotNull);
        expect(Validators.email('@example.com'), isNotNull);
      });

      test('ignora vazio', () {
        expect(Validators.email(''), isNull);
        expect(Validators.email(null), isNull);
      });
    });

    group('phone', () {
      test('valida telefones com 10 dígitos', () {
        expect(Validators.phone('1234567890'), isNull);
        expect(Validators.phone('(123) 456-7890'), isNull);
      });

      test('valida telefones com 11 dígitos', () {
        expect(Validators.phone('12345678901'), isNull);
      });

      test('rejeita telefones inválidos', () {
        expect(Validators.phone('123'), isNotNull);
        expect(Validators.phone('12345'), isNotNull);
      });
    });

    group('cpf', () {
      test('valida CPF correto', () {
        // CPF válido de teste
        expect(Validators.cpf('11144477735'), isNull);
      });

      test('rejeita CPF com dígitos incorretos', () {
        expect(Validators.cpf('00000000000'), isNotNull);
        expect(Validators.cpf('11111111111'), isNotNull);
      });

      test('rejeita CPF com 11 dígitos', () {
        expect(Validators.cpf('123'), isNotNull);
      });
    });

    group('cnpj', () {
      test('valida CNPJ correto', () {
        // CNPJ válido de teste
        expect(Validators.cnpj('11222333000181'), isNull);
      });

      test('rejeita CNPJ com dígitos incorretos', () {
        expect(Validators.cnpj('00000000000000'), isNotNull);
        expect(Validators.cnpj('11111111111111'), isNotNull);
      });

      test('rejeita CNPJ com comprimento errado', () {
        expect(Validators.cnpj('123'), isNotNull);
      });
    });

    group('minLength', () {
      test('valida comprimento mínimo', () {
        expect(Validators.minLength('hello', 5), isNull);
        expect(Validators.minLength('hello world', 5), isNull);
      });

      test('rejeita comprimento menor', () {
        expect(Validators.minLength('hi', 5), isNotNull);
      });
    });

    group('maxLength', () {
      test('valida comprimento máximo', () {
        expect(Validators.maxLength('hello', 5), isNull);
        expect(Validators.maxLength('hi', 5), isNull);
      });

      test('rejeita comprimento maior', () {
        expect(Validators.maxLength('hello world', 5), isNotNull);
      });
    });

    group('numeric', () {
      test('valida apenas números', () {
        expect(Validators.numeric('12345'), isNull);
        expect(Validators.numeric('0'), isNull);
      });

      test('rejeita com letras', () {
        expect(Validators.numeric('123abc'), isNotNull);
        expect(Validators.numeric('12.34'), isNotNull);
      });
    });

    group('minValue', () {
      test('valida valor mínimo', () {
        expect(Validators.minValue('100', 50), isNull);
        expect(Validators.minValue('50', 50), isNull);
      });

      test('rejeita valor menor', () {
        expect(Validators.minValue('40', 50), isNotNull);
      });
    });

    group('maxValue', () {
      test('valida valor máximo', () {
        expect(Validators.maxValue('50', 100), isNull);
        expect(Validators.maxValue('100', 100), isNull);
      });

      test('rejeita valor maior', () {
        expect(Validators.maxValue('150', 100), isNotNull);
      });
    });

    group('url', () {
      test('valida URLs corretas', () {
        expect(Validators.url('https://example.com'), isNull);
        expect(Validators.url('http://example.com/path'), isNull);
      });

      test('rejeita URLs sem protocolo', () {
        expect(Validators.url('example.com'), isNotNull);
      });

      test('rejeita URLs inválidas', () {
        expect(Validators.url('not a url'), isNotNull);
      });
    });

    group('date', () {
      test('valida datas válidas', () {
        expect(Validators.date('01/01/2024'), isNull);
        expect(Validators.date('31/12/2024'), isNull);
      });

      test('rejeita datas inválidas', () {
        expect(Validators.date('32/01/2024'), isNotNull);
        expect(Validators.date('01-01-2024'), isNotNull);
      });
    });

    group('match', () {
      test('valida campos iguais', () {
        expect(Validators.match('senha123', 'senha123'), isNull);
      });

      test('rejeita campos diferentes', () {
        expect(Validators.match('senha123', 'senha456'), isNotNull);
      });
    });
  });

  group('CompositeValidator', () {
    test('valida com múltiplos validadores', () {
      final validator = CompositeValidator()
          .add((value) => Validators.required(value))
          .add((value) => Validators.minLength(value, 5));

      expect(validator.validate(''), isNotNull);
      expect(validator.validate('hi'), isNotNull);
      expect(validator.validate('hello'), isNull);
    });

    test('retorna primeiro erro', () {
      final validator = CompositeValidator()
          .add((value) => Validators.required(value))
          .add((value) => Validators.email(value));

      final error = validator.validate('');
      expect(error, contains('obrigatório'));
    });
  });
}
