import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../paths/app_paths.dart';

/// Serviço JWT para autenticação segura
class JwtService {
  static const int _expirationHours = 24;

  static String? _secretCache;

  /// Segredo de assinatura, exclusivo desta instalação.
  ///
  /// Fica em `jwt.secret` na pasta de dados do usuário, gerado na primeira
  /// execução. Antes era uma constante no código: com o repositório público,
  /// qualquer um poderia assinar um token válido e ler ou gravar no ERP de
  /// qualquer cliente pela API do servidor embutido.
  static String get _secret {
    final emCache = _secretCache;
    if (emCache != null) return emCache;

    final arquivo = File(p.join(AppPaths.dataDir.path, 'jwt.secret'));
    if (arquivo.existsSync()) {
      final lido = arquivo.readAsStringSync().trim();
      if (lido.isNotEmpty) return _secretCache = lido;
    }

    final aleatorio = Random.secure();
    final bytes = List<int>.generate(32, (_) => aleatorio.nextInt(256));
    final novo = base64Url.encode(bytes);
    try {
      arquivo.writeAsStringSync(novo);
    } on FileSystemException {
      // Sem permissão de escrita o segredo vale só para esta execução: os
      // tokens expiram ao reiniciar, mas o servidor continua funcionando.
    }
    return _secretCache = novo;
  }

  /// Gera um token JWT
  static String generateToken(int userId, String userName, String perfil) {
    final now = DateTime.now();
    final expirationTime = now.add(Duration(hours: _expirationHours));

    // Header
    final header = jsonEncode({'alg': 'HS256', 'typ': 'JWT'});
    final headerEncoded = _base64Encode(header);

    // Payload
    final payload = jsonEncode({
      'sub': userId.toString(),
      'name': userName,
      'perfil': perfil,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expirationTime.millisecondsSinceEpoch ~/ 1000,
    });
    final payloadEncoded = _base64Encode(payload);

    // Signature
    final signature = _generateSignature('$headerEncoded.$payloadEncoded');

    return '$headerEncoded.$payloadEncoded.$signature';
  }

  /// Valida e decodifica um token JWT
  static Map<String, dynamic>? validateToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      // Verifica assinatura
      final signature = _generateSignature('${parts[0]}.${parts[1]}');
      if (signature != parts[2]) {
        return null;
      }

      // Decodifica payload
      final payload = _base64Decode(parts[1]);
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      // Verifica expiração
      final exp = decoded['exp'] as int?;
      if (exp != null) {
        final expirationTime =
            DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (expirationTime.isBefore(DateTime.now())) {
          return null; // Token expirado
        }
      }

      return decoded;
    } catch (e) {
      return null;
    }
  }

  /// Gera assinatura HMAC-SHA256
  static String _generateSignature(String message) {
    final key = utf8.encode(_secret);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return _base64Encode(digest.toString());
  }

  /// Codifica para base64 URL-safe
  static String _base64Encode(String str) {
    return base64Url
        .encode(utf8.encode(str))
        .toString()
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  /// Decodifica de base64 URL-safe
  static String _base64Decode(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw FormatException('Invalid base64url string');
    }
    return utf8.decode(base64Url.decode(output));
  }
}
