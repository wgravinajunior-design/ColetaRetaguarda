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
    // Normaliza entrada: remove espaços desnecessários
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    // Validações básicas
    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      _logger.warning('AuthService', 'Login attempt with empty credentials');
      return 'Usuário e senha são obrigatórios';
    }

    // Verifica rate limiting (proteção contra força bruta)
    final rateLimitError = await _rateLimiter.canAttemptLogin(cleanUsername);
    if (rateLimitError != null) {
      _logger.warning('AuthService', 'Login attempt blocked by rate limiter: $cleanUsername');
      return rateLimitError;
    }

    try {
      final db = await DbConnection().db;
      final q = db.query();

      // Debug: logar os valores sendo comparados (apenas em debug)
      if (kDebugMode) {
        debugPrint('[Login] Username: "$cleanUsername" | Password: "$cleanPassword"');
      }

      // Consulta na TB_USUARIO com senha em texto plano.
      //
      // A comparação é feita aqui, e não no WHERE, porque a TB_USUARIO vem do
      // ERP e cada instalação preencheu essas colunas à sua maneira:
      //
      //   - o login pode estar em qualquer caixa (JOAO, joao, João);
      //   - login e senha costumam vir com espaços à direita, porque a coluna
      //     é CHAR de tamanho fixo;
      //   - USU_STATUS em branco é comum em cadastro antigo, e tratá-lo como
      //     inativo trancava do lado de fora um usuário perfeitamente válido.
      //
      // O WHERE antigo exigia igualdade exata e USU_STATUS = 'A', então só
      // entrava quem tivesse sido cadastrado exatamente daquele jeito.
      await q.openCursor(
        sql: 'SELECT USU_ID, USU_NOME, USU_LOGIN, USU_SENHA, '
             'USU_ADMINISTRADOR, USU_STATUS FROM TB_USUARIO',
      );

      bool validLogin = false;
      bool achouLogin = false;
      bool inativo = false;
      String? nomeEncontrado;
      String? perfilEncontrado;

      // CHAR de tamanho fixo no Firebird às vezes vem preenchido com bytes
      // nulos (\0) em vez de espaços, a depender do charset da conexão.
      // String.trim() não remove \0, então sem essa limpeza extra a
      // comparação falha mesmo com login/senha corretos.
      String texto(dynamic v) =>
          v == null ? '' : '$v'.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();

      if (kDebugMode) {
        debugPrint(
          '[Login] Buscando login="$cleanUsername" (${cleanUsername.length} chars) '
          'senha="${cleanPassword.replaceAll(RegExp('.'), '*')}" (${cleanPassword.length} chars)',
        );
      }

      await for (var row in q.rows()) {
        final loginBanco = texto(row['USU_LOGIN']);
        if (loginBanco.toLowerCase() != cleanUsername.toLowerCase()) {
          continue;
        }
        achouLogin = true;
        final senhaBanco = texto(row['USU_SENHA']);
        if (kDebugMode) {
          debugPrint(
            '[Login] Login encontrado: "$loginBanco". '
            'Senha do banco tem ${senhaBanco.length} chars, códigos: '
            '${senhaBanco.codeUnits}. Senha digitada tem '
            '${cleanPassword.length} chars, códigos: ${cleanPassword.codeUnits}.',
          );
        }
        if (senhaBanco != cleanPassword) continue;

        final status = texto(row['USU_STATUS']).toUpperCase();
        if (status == 'I') {
          inativo = true;
          break;
        }

        validLogin = true;
        nomeEncontrado = texto(row['USU_NOME']);
        // O perfil vem de USU_ADMINISTRADOR ('S'/'N'), e não de USU_PERFIL:
        // nesta base USU_PERFIL é INTEGER — o código do grupo de permissões do
        // ERP —, então lê-lo como rótulo dava "1" e ninguém era reconhecido
        // como administrador. As telas de cadastro ficavam trancadas para
        // todo mundo.
        perfilEncontrado = texto(row['USU_ADMINISTRADOR']).toUpperCase() == 'S'
            ? 'Administrador'
            : 'Operador';
        break;
      }

      await q.close();

      if (inativo) {
        _logger.warning('AuthService', 'Login de usuário inativo: $cleanUsername');
        return 'Este usuário está inativo. Peça para reativá-lo em Usuários.';
      }

      if (validLogin) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'token_direto_firebird_${DateTime.now().millisecondsSinceEpoch}');
        await prefs.setString('auth_user', nomeEncontrado ?? cleanUsername);
        if (perfilEncontrado != null) {
          await prefs.setString('auth_perfil', perfilEncontrado);
        }

        _isAuthenticated = true;
        _userName = nomeEncontrado ?? cleanUsername;
        _userPerfil = perfilEncontrado;

        // Limpa histórico de tentativas após sucesso
        await _rateLimiter.clearLoginAttempts(cleanUsername);

        _logger.info('AuthService', 'Successful login for user: $cleanUsername (perfil: $perfilEncontrado)');
        notifyListeners();
        return null;
      } else {
        // Registra tentativa falhada
        await _rateLimiter.recordFailedAttempt(cleanUsername);
        _logger.warning('AuthService', 'Failed login attempt for user: $cleanUsername');
        // Distinguir os dois casos poupa muita adivinhação: "senha incorreta"
        // diz que a base é a certa e o usuário existe; "não encontrado" quase
        // sempre é base errada nas Configurações.
        return achouLogin
            ? 'Senha incorreta.'
            : 'Usuário "$cleanUsername" não existe nesta base.';
      }
    } catch (e) {
      _logger.error('AuthService', 'Database error during login: $e');
      // Registra tentativa falhada por erro
      await _rateLimiter.recordFailedAttempt(cleanUsername);
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
