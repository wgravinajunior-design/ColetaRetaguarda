import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/db_connection.dart';
import '../../core/security/rate_limiter.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;
  final RateLimiter _rateLimiter = RateLimiter();

  bool get isAuthenticated => _isAuthenticated;
  String? get userName => _userName;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Forçando o logout para limpar o MOCK antigo e obrigar a tela de login a aparecer
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    // Verifica rate limiting
    final errorMessage = await _rateLimiter.canAttemptLogin(username);
    if (errorMessage != null) {
      return errorMessage;
    }

    try {
      final db = await DbConnection().db;

      final q = db.query();
      // Consulta na TB_USUARIO exatamente como o Delphi faz (UFormLogin)
      await q.openCursor(
        sql: "SELECT USU_ID, USU_NOME, USU_PERFIL FROM TB_USUARIO WHERE USU_LOGIN = ? AND USU_SENHA = ? AND USU_STATUS = 'A'",
        parameters: [username, password],
      );

      bool validLogin = false;
      String? nomeEncontrado;

      await for (var row in q.rows()) {
        validLogin = true;
        nomeEncontrado = row['USU_NOME'];
        break; // achou o usuário
      }

      await q.close();

      if (validLogin) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'token_direto_firebird');
        await prefs.setString('auth_user', nomeEncontrado ?? username);

        _isAuthenticated = true;
        _userName = nomeEncontrado ?? username;

        // Limpa histórico de tentativas após sucesso
        await _rateLimiter.clearLoginAttempts(username);

        notifyListeners();
        return null; // Sucesso
      } else {
        // Registra tentativa falhada
        await _rateLimiter.recordFailedAttempt(username);
        return 'Usuário ou senha inválidos';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro no login (Firebird DB): $e');
      }
      // Registra tentativa falhada por erro
      await _rateLimiter.recordFailedAttempt(username);
      return 'Erro ao conectar com banco de dados';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');

    _isAuthenticated = false;
    _userName = null;
    notifyListeners();
  }
}
