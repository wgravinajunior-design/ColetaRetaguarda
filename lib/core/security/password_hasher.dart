import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Utilitário seguro para hashing de senhas usando SHA-256 com salt
///
/// Nota: Para máxima segurança, as senhas devem ser armazenadas com bcrypt
/// no servidor, mas como este app conecta diretamente ao Firebird,
/// usamos SHA-256 com salt como camada de proteção.
class PasswordHasher {
  static final PasswordHasher _instance = PasswordHasher._internal();

  factory PasswordHasher() {
    return _instance;
  }

  PasswordHasher._internal();

  /// Salt padrão para hashing (em produção, usar individual por usuário)
  /// Este salt é fixo apenas para compatibilidade com senhas armazenadas no Firebird
  static const String _defaultSalt = 'coleta_erp_app_salt_2024';

  /// Hasheia uma senha usando SHA-256 com salt
  ///
  /// Exemplo:
  /// ```dart
  /// final hashedPassword = PasswordHasher().hashPassword('minhasenha123');
  /// ```
  String hashPassword(String password, {String? salt}) {
    final usedSalt = salt ?? _defaultSalt;
    final combined = '$password$usedSalt';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Valida se uma senha em texto plano corresponde a um hash armazenado
  ///
  /// Exemplo:
  /// ```dart
  /// final isValid = PasswordHasher().verifyPassword('minhasenha123', storedHash);
  /// ```
  bool verifyPassword(String plainPassword, String storedHash, {String? salt}) {
    final hashedAttempt = hashPassword(plainPassword, salt: salt);
    return hashedAttempt == storedHash;
  }

  /// Gera um salt único para um usuário (recomendado para novo usuários)
  /// Formato: user_<username>_salt_<timestamp>
  String generateSalt(String username) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'user_${username.replaceAll(' ', '_')}_salt_$timestamp';
  }

  /// Hasheia com salt gerado para novo usuário
  /// Retorna um objeto com hash e salt para armazenar no banco
  PasswordHashResult hashPasswordWithSalt(String password, String username) {
    final salt = generateSalt(username);
    final hash = hashPassword(password, salt: salt);
    return PasswordHashResult(hash: hash, salt: salt);
  }
}

/// Resultado do hashing de senha com salt
class PasswordHashResult {
  final String hash;
  final String salt;

  PasswordHashResult({
    required this.hash,
    required this.salt,
  });

  @override
  String toString() => 'PasswordHashResult(hash: ${hash.substring(0, 16)}..., salt: $salt)';
}
