/// Validadores de campos do formulário
abstract class Validators {
  /// Valida email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email é obrigatório';
    }
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  /// Valida CPF (11 dígitos)
  static String? cpf(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 11) {
      return 'CPF deve ter 11 dígitos';
    }
    return null;
  }

  /// Valida CNPJ (14 dígitos)
  static String? cnpj(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 14) {
      return 'CNPJ deve ter 14 dígitos';
    }
    return null;
  }

  /// Valida CPF ou CNPJ
  static String? cpfOrCnpj(String? value) {
    if (value == null || value.isEmpty) {
      return 'CPF/CNPJ é obrigatório';
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 11) {
      return cpf(value);
    } else if (clean.length == 14) {
      return cnpj(value);
    }
    return 'CPF/CNPJ inválido';
  }

  /// Valida telefone (10-11 dígitos)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 10 || clean.length > 11) {
      return 'Telefone deve ter 10-11 dígitos';
    }
    return null;
  }

  /// Valida CEP (8 dígitos)
  static String? cep(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) {
      return 'CEP deve ter 8 dígitos';
    }
    return null;
  }

  /// Valida campo obrigatório
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      final field = fieldName ?? 'Campo';
      return '$field é obrigatório';
    }
    return null;
  }

  /// Valida comprimento mínimo
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length < min) {
      final field = fieldName ?? 'Campo';
      return '$field deve ter no mínimo $min caracteres';
    }
    return null;
  }

  /// Valida comprimento máximo
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length > max) {
      final field = fieldName ?? 'Campo';
      return '$field deve ter no máximo $max caracteres';
    }
    return null;
  }

  /// Valida número
  static String? number(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      num.parse(value);
      return null;
    } catch (e) {
      final field = fieldName ?? 'Campo';
      return '$field deve ser um número válido';
    }
  }
}
