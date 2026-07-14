import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/db_connection.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userName;

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

  Future<bool> login(String username, String password) async {
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
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro no login (Firebird DB): $e');
      }
      return false; // Retorna falso se der erro ou usuário for incorreto
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
