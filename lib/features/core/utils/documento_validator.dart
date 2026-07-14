/// Utilitário para validação e formatação de CPF/CNPJ.
class DocumentoValidator {
  /// Remove tudo que não for dígito.
  static String apenasNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Valida CPF (11 dígitos) usando os dígitos verificadores.
  static bool validarCpf(String cpf) {
    final n = apenasNumeros(cpf);
    if (n.length != 11) return false;
    // Rejeita sequências repetidas (000..., 111..., etc.)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(n)) return false;

    int calcDigito(int qtd) {
      int soma = 0;
      for (int i = 0; i < qtd; i++) {
        soma += int.parse(n[i]) * ((qtd + 1) - i);
      }
      final resto = (soma * 10) % 11;
      return resto == 10 ? 0 : resto;
    }

    final d1 = calcDigito(9);
    final d2 = calcDigito(10);
    return d1 == int.parse(n[9]) && d2 == int.parse(n[10]);
  }

  /// Valida CNPJ (14 dígitos) usando os dígitos verificadores.
  static bool validarCnpj(String cnpj) {
    final n = apenasNumeros(cnpj);
    if (n.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(n)) return false;

    int calc(List<int> pesos) {
      int soma = 0;
      for (int i = 0; i < pesos.length; i++) {
        soma += int.parse(n[i]) * pesos[i];
      }
      final resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    final d1 = calc([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    final d2 = calc([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    return d1 == int.parse(n[12]) && d2 == int.parse(n[13]);
  }

  /// Valida CPF ou CNPJ conforme a quantidade de dígitos.
  static bool validar(String documento) {
    final n = apenasNumeros(documento);
    if (n.length == 11) return validarCpf(n);
    if (n.length == 14) return validarCnpj(n);
    return false;
  }

  /// Mensagem de erro apropriada, ou null se válido/vazio.
  static String? mensagemErro(String documento, {bool obrigatorio = false}) {
    final n = apenasNumeros(documento);
    if (n.isEmpty) {
      return obrigatorio ? 'Informe o CPF ou CNPJ' : null;
    }
    if (n.length != 11 && n.length != 14) {
      return 'CPF deve ter 11 e CNPJ 14 dígitos';
    }
    if (!validar(n)) {
      return n.length == 11 ? 'CPF inválido' : 'CNPJ inválido';
    }
    return null;
  }

  /// Formata como CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00).
  static String formatar(String documento) {
    final n = apenasNumeros(documento);
    if (n.length == 11) {
      return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6, 9)}-${n.substring(9)}';
    }
    if (n.length == 14) {
      return '${n.substring(0, 2)}.${n.substring(2, 5)}.${n.substring(5, 8)}/${n.substring(8, 12)}-${n.substring(12)}';
    }
    return documento;
  }
}
