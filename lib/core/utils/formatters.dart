/// Formatadores de dados
abstract class Formatters {
  /// Formata CPF: XXX.XXX.XXX-XX
  static String formatCpf(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 3) return clean;
    if (clean.length <= 6) {
      return '${clean.substring(0, 3)}.${clean.substring(3)}';
    }
    if (clean.length <= 9) {
      return '${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6)}';
    }
    return '${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6, 9)}-${clean.substring(9, 11)}';
  }

  /// Formata CNPJ: XX.XXX.XXX/XXXX-XX
  static String formatCnpj(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 2) return clean;
    if (clean.length <= 5) {
      return '${clean.substring(0, 2)}.${clean.substring(2)}';
    }
    if (clean.length <= 8) {
      return '${clean.substring(0, 2)}.${clean.substring(2, 5)}.${clean.substring(5)}';
    }
    if (clean.length <= 12) {
      return '${clean.substring(0, 2)}.${clean.substring(2, 5)}.${clean.substring(5, 8)}/${clean.substring(8)}';
    }
    return '${clean.substring(0, 2)}.${clean.substring(2, 5)}.${clean.substring(5, 8)}/${clean.substring(8, 12)}-${clean.substring(12, 14)}';
  }

  /// Formata CEP: XXXXX-XXX
  static String formatCep(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 5) return clean;
    return '${clean.substring(0, 5)}-${clean.substring(5)}';
  }

  /// Formata telefone: (XX) XXXX-XXXX ou (XX) XXXXX-XXXX
  static String formatPhone(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 2) return '($clean';
    if (clean.length <= 6) {
      return '(${clean.substring(0, 2)}) ${clean.substring(2)}';
    }
    if (clean.length <= 10) {
      return '(${clean.substring(0, 2)}) ${clean.substring(2, 6)}-${clean.substring(6)}';
    }
    return '(${clean.substring(0, 2)}) ${clean.substring(2, 7)}-${clean.substring(7)}';
  }

  /// Remove formatação (retorna apenas dígitos)
  static String unformat(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  /// Formata data: DD/MM/YYYY
  static String formatDate(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    if (clean.length <= 2) return clean;
    if (clean.length <= 4) {
      return '${clean.substring(0, 2)}/${clean.substring(2)}';
    }
    return '${clean.substring(0, 2)}/${clean.substring(2, 4)}/${clean.substring(4)}';
  }

  /// Formata valor monetário
  static String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Formata quantidade decimal
  static String formatDecimal(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }
}
