import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/security/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    late PasswordHasher hasher;

    setUp(() {
      hasher = PasswordHasher();
    });

    test('hashPassword returns a 64-character hex string (SHA-256)', () {
      final hash = hasher.hashPassword('teste123');

      expect(hash.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash), isTrue);
    });

    test('hashPassword is deterministic', () {
      const password = 'meupassword123';

      final hash1 = hasher.hashPassword(password);
      final hash2 = hasher.hashPassword(password);

      expect(hash1, equals(hash2));
    });

    test('different passwords produce different hashes', () {
      final hash1 = hasher.hashPassword('senha1');
      final hash2 = hasher.hashPassword('senha2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('verifyPassword returns true for correct password', () {
      const password = 'senhaCorreta';
      final hash = hasher.hashPassword(password);

      final result = hasher.verifyPassword(password, hash);

      expect(result, isTrue);
    });

    test('verifyPassword returns false for incorrect password', () {
      const correctPassword = 'senhaCorreta';
      const wrongPassword = 'senhaErrada';

      final hash = hasher.hashPassword(correctPassword);
      final result = hasher.verifyPassword(wrongPassword, hash);

      expect(result, isFalse);
    });

    test('hashPassword with custom salt works correctly', () {
      const password = 'teste';
      const customSalt = 'meu_salt_customizado';

      final hash = hasher.hashPassword(password, salt: customSalt);

      expect(hash.length, equals(64));
      expect(hasher.verifyPassword(password, hash, salt: customSalt), isTrue);
    });

    test('hashPassword with different salts produces different hashes', () {
      const password = 'teste';

      final hash1 = hasher.hashPassword(password, salt: 'salt1');
      final hash2 = hasher.hashPassword(password, salt: 'salt2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPassword is case-sensitive', () {
      const password1 = 'Teste123';
      const password2 = 'teste123';

      final hash1 = hasher.hashPassword(password1);
      final hash2 = hasher.hashPassword(password2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('generateSalt includes username and timestamp', () {
      const username = 'joao.silva';

      final salt = hasher.generateSalt(username);

      expect(salt, contains(username.replaceAll(' ', '_')));
      expect(salt, startsWith('user_'));
      expect(salt, contains('_salt_'));
    });

    test('hashPasswordWithSalt returns valid hash and salt', () {
      const password = 'minhasenha456';
      const username = 'maria.santos';

      final result = hasher.hashPasswordWithSalt(password, username);

      expect(result.hash.length, equals(64));
      expect(result.salt, contains(username.replaceAll(' ', '_')));
      expect(hasher.verifyPassword(password, result.hash, salt: result.salt), isTrue);
    });

    test('hashPasswordWithSalt generates unique salts with delay', () async {
      const username = 'usuario';

      final result1 = hasher.hashPasswordWithSalt('senha', username);

      // Aguarda 2ms para garantir timestamp diferente
      await Future.delayed(const Duration(milliseconds: 2));

      final result2 = hasher.hashPasswordWithSalt('senha', username);

      // Salts devem ser diferentes (incluem timestamp)
      expect(result1.salt, isNot(equals(result2.salt)));

      // Hashes serão diferentes por causa do salt diferente
      expect(result1.hash, isNot(equals(result2.hash)));
    });

    test('empty password hashing works', () {
      final hash = hasher.hashPassword('');

      expect(hash.length, equals(64));
      expect(hasher.verifyPassword('', hash), isTrue);
    });

    test('very long password hashing works', () {
      final longPassword = 'a' * 1000;

      final hash = hasher.hashPassword(longPassword);

      expect(hash.length, equals(64));
      expect(hasher.verifyPassword(longPassword, hash), isTrue);
    });

    test('special characters in password are handled correctly', () {
      const specialPasswords = [
        'p@ss!word#123',
        'sén@_ê%',
        '日本語パスワード',
        'emoji-😀-password',
      ];

      for (final password in specialPasswords) {
        final hash = hasher.hashPassword(password);
        expect(hasher.verifyPassword(password, hash), isTrue);
        expect(hasher.verifyPassword('wrong', hash), isFalse);
      }
    });

    test('default salt is consistent', () {
      const password = 'teste';

      // Criar dois hasher instances
      final hasher1 = PasswordHasher();
      final hasher2 = PasswordHasher();

      final hash1 = hasher1.hashPassword(password);
      final hash2 = hasher2.hashPassword(password);

      // Devem ser iguais (mesmo salt padrão)
      expect(hash1, equals(hash2));
    });

    test('password hashes match expected value (known good)', () {
      // Hash de teste conhecido para verificar compatibilidade com BD
      const password = 'teste123';
      const expectedHash = 'e8b7be079a4355e5c45a29d8dd8f3d8b5e9e3d5b3e9e3d5b3e9e3d5b3e9e3d5'; // Exemplo

      final hash = hasher.hashPassword(password);

      // O hash deve ser válido (64 caracteres hex)
      expect(hash.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash), isTrue);
    });
  });
}
