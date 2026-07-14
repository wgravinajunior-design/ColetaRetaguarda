import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/db_connection.dart';
import '../../core/security/rate_limiter.dart';
import '../../core/logging/app_logger.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  String? _userPerfil;
  final RateLimiter _rateLimiter = RateLimiter();
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
      _logger.warning('AuthService', 'Login attempt with empty credentials');
      return 'Usuário e senha são obrigatórios';
    }

    // Verifica rate limiting (proteção contra força bruta)
    final rateLimitError = await _rateLimiter.canAttemptLogin(username);
    if (rateLimitError != null) {
      _logger.warning('AuthService', 'Login attempt blocked by rate limiter: $username');
      return rateLimitError;
    }

    try {
      final db = await DbConnection().db;
      final q = db.query();

      // Consulta na TB_USUARIO com senha em texto plano
      await q.openCursor(
        sql: "SELECT USU_ID, USU_NOME, USU_PERFIL FROM TB_USUARIO "
             "WHERE USU_LOGIN = ? AND USU_SENHA = ? AND USU_STATUS = 'A'",
        parameters: [username, password],
      );

      bool validLogin = false;
      String? nomeEncontrado;
      String? perfilEncontrado;

      await for (var row in q.rows()) {
        validLogin = true;
        nomeEncontrado = row['USU_NOME'];
        perfilEncontrado = row['USU_PERFIL'];
        break;
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

        _logger.info('AuthService', 'Successful login for user: $username (perfil: $perfilEncontrado)');
        notifyListeners();
        return null;
      } else {
        // Registra tentativa falhada
        await _rateLimiter.recordFailedAttempt(username);
        _logger.warning('AuthService', 'Failed login attempt for user: $username');
        return 'Usuário ou senha inválidos';
      }
    } catch (e) {
      _logger.error('AuthService', 'Database error during login: $e');
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

    _logger.info('AuthService', 'User logged out');
    notifyListeners();
  }
}
