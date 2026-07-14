/// Sistema centralizado de validadores para formulários
class Validators {
  /// Valida se o campo não está vazio
  static String? required(String? value, {String label = 'Campo'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label é obrigatório';
    }
    return null;
  }

  /// Valida email
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }

  /// Valida telefone (apenas números)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;

    final cleanPhone = value.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return 'Telefone deve ter 10 ou 11 dígitos';
    }
    return null;
  }

  /// Valida CPF
  static String? cpf(String? value) {
    if (value == null || value.isEmpty) return null;

    final cleanCpf = value.replaceAll(RegExp(r'\D'), '');
    if (cleanCpf.length != 11) {
      return 'CPF deve ter 11 dígitos';
    }

    if (!_isValidCpf(cleanCpf)) {
      return 'CPF inválido';
    }
    return null;
  }

  /// Valida CNPJ
  static String? cnpj(String? value) {
    if (value == null || value.isEmpty) return null;

    final cleanCnpj = value.replaceAll(RegExp(r'\D'), '');
    if (cleanCnpj.length != 14) {
      return 'CNPJ deve ter 14 dígitos';
    }

    if (!_isValidCnpj(cleanCnpj)) {
      return 'CNPJ inválido';
    }
    return null;
  }

  /// Valida comprimento mínimo
  static String? minLength(String? value, int length, {String label = 'Campo'}) {
    if (value == null || value.isEmpty) return null;

    if (value.length < length) {
      return '$label deve ter no mínimo $length caracteres';
    }
    return null;
  }

  /// Valida comprimento máximo
  static String? maxLength(String? value, int length, {String label = 'Campo'}) {
    if (value == null || value.isEmpty) return null;

    if (value.length > length) {
      return '$label deve ter no máximo $length caracteres';
    }
    return null;
  }

  /// Valida número
  static String? numeric(String? value, {String label = 'Campo'}) {
    if (value == null || value.isEmpty) return null;

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return '$label deve conter apenas números';
    }
    return null;
  }

  /// Valida valor mínimo
  static String? minValue(String? value, double minVal, {String label = 'Campo'}) {
    if (value == null || value.isEmpty) return null;

    final numVal = double.tryParse(value);
    if (numVal == null || numVal < minVal) {
      return '$label deve ser no mínimo $minVal';
    }
    return null;
  }

  /// Valida valor máximo
  static String? maxValue(String? value, double maxVal, {String label = 'Campo'}) {
    if (value == null || value.isEmpty) return null;

    final numVal = double.tryParse(value);
    if (numVal == null || numVal > maxVal) {
      return '$label deve ser no máximo $maxVal';
    }
    return null;
  }

  /// Valida URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      Uri.parse(value);
      if (!value.startsWith('http://') && !value.startsWith('https://')) {
        return 'URL deve começar com http:// ou https://';
      }
      return null;
    } catch (e) {
      return 'URL inválida';
    }
  }

  /// Valida data (dd/mm/yyyy)
  static String? date(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      final parts = value.split('/');
      if (parts.length != 3) return 'Data deve estar no formato dd/mm/yyyy';

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (day < 1 || day > 31 || month < 1 || month > 12 || year < 1900) {
        return 'Data inválida';
      }

      DateTime(year, month, day);
      return null;
    } catch (e) {
      return 'Data inválida';
    }
  }

  /// Valida se dois campos são iguais
  static String? match(String? value, String? compareValue, {String label = 'Campo'}) {
    if (value == null || compareValue == null) return null;

    if (value != compareValue) {
      return '$label não corresponde';
    }
    return null;
  }

  /// Calcula e valida CPF
  static bool _isValidCpf(String cpf) {
    if (cpf.replaceAll(RegExp(r'\D'), '').length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }

    int remainder = sum % 11;
    int digit1 = remainder < 2 ? 0 : 11 - remainder;

    if (int.parse(cpf[9]) != digit1) return false;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }

    remainder = sum % 11;
    int digit2 = remainder < 2 ? 0 : 11 - remainder;

    return int.parse(cpf[10]) == digit2;
  }

  /// Calcula e valida CNPJ
  static bool _isValidCnpj(String cnpj) {
    if (cnpj.replaceAll(RegExp(r'\D'), '').length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    int sum = 0;
    int multiplier = 5;

    for (int i = 0; i < 12; i++) {
      sum += int.parse(cnpj[i]) * multiplier;
      multiplier = multiplier == 2 ? 9 : multiplier - 1;
    }

    int remainder = sum % 11;
    int digit1 = remainder < 2 ? 0 : 11 - remainder;

    sum = 0;
    multiplier = 6;

    for (int i = 0; i < 13; i++) {
      sum += int.parse(cnpj[i]) * multiplier;
      multiplier = multiplier == 2 ? 9 : multiplier - 1;
    }

    remainder = sum % 11;
    int digit2 = remainder < 2 ? 0 : 11 - remainder;

    return int.parse(cnpj[12]) == digit1 && int.parse(cnpj[13]) == digit2;
  }
}

/// Combinador de validadores
class CompositeValidator {
  final List<String? Function(String?)> _validators = [];

  CompositeValidator add(String? Function(String?) validator) {
    _validators.add(validator);
    return this;
  }

  String? validate(String? value) {
    for (final validator in _validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  }
}
