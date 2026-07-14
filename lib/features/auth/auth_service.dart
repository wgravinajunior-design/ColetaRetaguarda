import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/db_connection.dart';
import '../../core/security/rate_limiter.dart';
import '../../core/security/password_hasher.dart';
import '../../core/logging/app_logger.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  String? _userPerfil;
  final RateLimiter _rateLimiter = RateLimiter();
  final PasswordHasher _passwordHasher = PasswordHasher();
  final AppLogger _logger = AppLogger();

  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;
  String? get userPerfil => _userPerfil;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Forçando o logout para limpar o MOCK antigo e obrigar a tela de login a aparecer
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    // Validações básicas
    if (username.trim().isEmpty || password.isEmpty) {
      _logger.warning('Login attempt with empty credentials');
      return 'Usuário e senha são obrigatórios';
    }

    // Verifica rate limiting (proteção contra força bruta)
    final rateLimitError = await _rateLimiter.canAttemptLogin(username);
    if (rateLimitError != null) {
      _logger.warning('Login attempt blocked by rate limiter: $username');
      return rateLimitError;
    }

    try {
      // Hash da senha (segurança: nunca enviar senha em texto plano)
      final hashedPassword = _passwordHasher.hashPassword(password);

      final db = await DbConnection().db;
      final q = db.query();

      // IMPORTANTE: A senha no banco deve estar armazenada como SHA-256 hash
      // Nunca use senhas em texto plano!
      // Padrão de comparação:
      // 1. Desenvolvimento: USU_SENHA pode ser hash SHA-256
      // 2. Produção: DEVE ser bcrypt ou argon2 no servidor
      await q.openCursor(
        sql: "SELECT USU_ID, USU_NOME, USU_PERFIL FROM TB_USUARIO "
             "WHERE USU_LOGIN = ? AND USU_SENHA = ? AND USU_STATUS = 'A'",
        parameters: [username, hashedPassword],
      );

      bool validLogin = false;
      String? nomeEncontrado;
      String? perfilEncontrado;

      await for (var row in q.rows()) {
        validLogin = true;
        nomeEncontrado = row['USU_NOME'];
        perfilEncontrado = row['USU_PERFIL'];
        break; // encontrou o usuário
      }

      await q.close();

      if (validLogin) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'token_direto_firebird_${DateTime.now().millisecondsSinceEpoch}');
        await prefs.setString('auth_user', nomeEncontrado ?? username);
        if (perfilEncontrado != null) {
          await prefs.setString('auth_perfil', perfilEncontrado);
        }

        _isAuthenticated = true;
        _userName = nomeEncontrado ?? username;
        _userPerfil = perfilEncontrado;

        // Limpa histórico de tentativas após sucesso
        await _rateLimiter.clearLoginAttempts(username);

        _logger.info('Successful login for user: $username (perfil: $perfilEncontrado)');
        notifyListeners();
        return null; // Sucesso
      } else {
        // Registra tentativa falhada
        await _rateLimiter.recordFailedAttempt(username);
        _logger.warning('Failed login attempt for user: $username');
        return 'Usuário ou senha inválidos';
      }
    } catch (e) {
      _logger.error('Database error during login: $e');
      // Registra tentativa falhada por erro
      await _rateLimiter.recordFailedAttempt(username);
      return 'Erro ao conectar com banco de dados. Verifique a configuração.';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('auth_perfil');

    _isAuthenticated = false;
    _userName = null;
    _userPerfil = null;

    _logger.info('User logged out: $_userName');
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
