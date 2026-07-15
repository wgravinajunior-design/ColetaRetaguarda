import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:io';
import '../logging/app_logger.dart';
import '../../features/core/database/db_connection.dart';
import 'package:firebird/firebird.dart';

/// Servidor HTTP integrado para sincronização mobile ↔ desktop
/// Roda em isolate separado para não bloquear UI
class ApiServer {
  static const int DEFAULT_PORT = 8080;
  static late AppLogger _logger;
  static HttpServer? _server;

  /// Inicia o servidor HTTP
  static Future<void> start({int port = DEFAULT_PORT}) async {
    _logger = AppLogger();

    try {
      final router = Router()
        ..get('/health', _health)
        ..post('/auth/login', _login)
        ..get('/coleta/pessoas', _listPessoas)
        ..post('/coleta/pessoas', _createPessoa)
        ..put('/coleta/pessoas/<id>', _updatePessoa)
        ..delete('/coleta/pessoas/<id>', _deletePessoa)
        ..get('/coleta/motoristas', _listMotoristas)
        ..post('/coleta/motoristas', _createMotorista)
        ..put('/coleta/motoristas/<id>', _updateMotorista)
        ..delete('/coleta/motoristas/<id>', _deleteMotorista)
        ..get('/coleta/veiculos', _listVeiculos)
        ..post('/coleta/veiculos', _createVeiculo)
        ..put('/coleta/veiculos/<id>', _updateVeiculo)
        ..delete('/coleta/veiculos/<id>', _deleteVeiculo)
        ..get('/coleta/rotas', _listRotas)
        ..post('/coleta/rotas', _createRota)
        ..put('/coleta/rotas/<id>', _updateRota)
        ..delete('/coleta/rotas/<id>', _deleteRota);

      // Middleware de logging
      final handler = shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_corsMiddleware)
          .addHandler(router);

      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _logger.info('ApiServer', 'Servidor iniciado em http://0.0.0.0:$port');
    } catch (e) {
      _logger.error('ApiServer', 'Erro ao iniciar servidor: $e');
      rethrow;
    }
  }

  /// Middleware CORS para permitir requisições do mobile
  static shelf.Middleware _corsMiddleware = (innerHandler) {
    return (request) async {
      // Responder a preflight requests
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok(null, headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }

      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
    };
  };

  /// Health check
  static shelf.Response _health(shelf.Request request) {
    return shelf.Response.ok(
      jsonEncode({'status': 'ok', 'server': 'Coleta Retaguarda'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /auth/login
  static Future<shelf.Response> _login(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final login = data['login'] as String?;
      final senha = data['senha'] as String?;

      if (login == null || senha == null) {
        return shelf.Response(400,
            body: jsonEncode({'error': 'Login e senha obrigatórios'}),
            headers: {'Content-Type': 'application/json'});
      }

      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT USU_ID, USU_NOME, USU_PERFIL FROM TB_USUARIO '
            'WHERE USU_LOGIN = ? AND USU_SENHA = ? AND USU_STATUS = \'A\'',
        parameters: [login, senha],
      );

      var found = false;
      late String nome;
      late String perfil;

      await for (var row in query.rows()) {
        found = true;
        nome = row['USU_NOME'];
        perfil = row['USU_PERFIL'] ?? 'OPERADOR';
        break;
      }

      await query.close();

      if (!found) {
        _logger.warning('ApiServer', 'Falha de login: $login');
        return shelf.Response(401,
            body: jsonEncode({'error': 'Credenciais inválidas'}),
            headers: {'Content-Type': 'application/json'});
      }

      final token = _generateToken(login, nome);
      _logger.info('ApiServer', 'Login OK: $login ($perfil)');

      return shelf.Response.ok(
        jsonEncode({
          'success': true,
          'token': token,
          'id': login,
          'nome': nome,
          'perfil': perfil,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.error('ApiServer', 'Erro no login: $e');
      return shelf.Response(500,
          body: jsonEncode({'error': 'Erro interno'}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  // ============ PESSOAS (PRODUTORES) ============

  static Future<shelf.Response> _listPessoas(shelf.Request request) async {
    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
            'PES_LONGITUDE, PES_VOLUME_MEDIO, PES_HR_COLETA, PES_KM, '
            'PES_STATUS FROM TB_PESSOA WHERE PES_FORNECEDOR = \'S\' '
            'ORDER BY PES_RSOCIAL_NOME',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['PES_ID'],
          'nome': row['PES_RSOCIAL_NOME'],
          'endereco': row['PES_ENDERECO'] ?? '',
          'latitude': row['PES_LATITUDE'] ?? 0.0,
          'longitude': row['PES_LONGITUDE'] ?? 0.0,
          'volume_medio': row['PES_VOLUME_MEDIO'] ?? 0.0,
          'hr_coleta': row['PES_HR_COLETA'] ?? '',
          'km': row['PES_KM'] ?? 0.0,
          'status': row['PES_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
        });
      }

      await query.close();

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar pessoas: $e');
    }
  }

  static Future<shelf.Response> _createPessoa(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'INSERT INTO TB_PESSOA (PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
          'PES_LONGITUDE, PES_VOLUME_MEDIO, PES_HR_COLETA, PES_KM, PES_STATUS, '
          'PES_FORNECEDOR, PES_TIPO_PESSOA) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

      query.Params.ByName('PES_RSOCIAL_NOME').AsString = data['nome'] ?? '';
      query.Params.ByName('PES_ENDERECO').AsString = data['endereco'] ?? '';
      query.Params.ByName('PES_LATITUDE').AsFloat = data['latitude'] ?? 0.0;
      query.Params.ByName('PES_LONGITUDE').AsFloat = data['longitude'] ?? 0.0;
      query.Params.ByName('PES_VOLUME_MEDIO').AsFloat =
          data['volume_medio'] ?? 0.0;
      query.Params.ByName('PES_HR_COLETA').AsString = data['hr_coleta'] ?? '';
      query.Params.ByName('PES_KM').AsFloat = data['km'] ?? 0.0;
      query.Params.ByName('PES_STATUS').AsString = 'A';
      query.Params.ByName('PES_FORNECEDOR').AsString = 'S';
      query.Params.ByName('PES_TIPO_PESSOA').AsString = 'P';

      query.Execute();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': query.LastInsertId}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar pessoa: $e');
    }
  }

  static Future<shelf.Response> _updatePessoa(
      shelf.Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final pesId = int.tryParse(id) ?? 0;

      if (pesId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL = 'UPDATE TB_PESSOA SET PES_RSOCIAL_NOME = ?, '
          'PES_ENDERECO = ?, PES_LATITUDE = ?, PES_LONGITUDE = ?, '
          'PES_VOLUME_MEDIO = ?, PES_HR_COLETA = ?, PES_KM = ? '
          'WHERE PES_ID = ?';

      query.Params.ByName('PES_RSOCIAL_NOME').AsString = data['nome'] ?? '';
      query.Params.ByName('PES_ENDERECO').AsString = data['endereco'] ?? '';
      query.Params.ByName('PES_LATITUDE').AsFloat = data['latitude'] ?? 0.0;
      query.Params.ByName('PES_LONGITUDE').AsFloat = data['longitude'] ?? 0.0;
      query.Params.ByName('PES_VOLUME_MEDIO').AsFloat =
          data['volume_medio'] ?? 0.0;
      query.Params.ByName('PES_HR_COLETA').AsString = data['hr_coleta'] ?? '';
      query.Params.ByName('PES_KM').AsFloat = data['km'] ?? 0.0;
      query.Params.ByName('PES_ID').AsInteger = pesId;

      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar pessoa: $e');
    }
  }

  static Future<shelf.Response> _deletePessoa(
      shelf.Request request, String id) async {
    try {
      final pesId = int.tryParse(id) ?? 0;
      if (pesId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ?';
      query.Params.ByName('PES_ID').AsInteger = pesId;
      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar pessoa: $e');
    }
  }

  // ============ MOTORISTAS ============
  // Implementar similar a PESSOAS...
  static Future<shelf.Response> _listMotoristas(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _createMotorista(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _updateMotorista(
          shelf.Request request, String id) async =>
      _notImplemented();
  static Future<shelf.Response> _deleteMotorista(
          shelf.Request request, String id) async =>
      _notImplemented();

  // ============ VEICULOS ============
  static Future<shelf.Response> _listVeiculos(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _createVeiculo(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _updateVeiculo(
          shelf.Request request, String id) async =>
      _notImplemented();
  static Future<shelf.Response> _deleteVeiculo(
          shelf.Request request, String id) async =>
      _notImplemented();

  // ============ ROTAS ============
  static Future<shelf.Response> _listRotas(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _createRota(shelf.Request request) async =>
      _notImplemented();
  static Future<shelf.Response> _updateRota(
          shelf.Request request, String id) async =>
      _notImplemented();
  static Future<shelf.Response> _deleteRota(
          shelf.Request request, String id) async =>
      _notImplemented();

  // ============ HELPERS ============

  static shelf.Response _errorResponse(int statusCode, String message) {
    return shelf.Response(statusCode,
        body: jsonEncode({'error': message, 'success': false}),
        headers: {'Content-Type': 'application/json'});
  }

  static shelf.Response _notImplemented() {
    return _errorResponse(501, 'Endpoint não implementado ainda');
  }

  static String _generateToken(String login, String nome) {
    // Token simples (em produção usar JWT real)
    return base64Encode(utf8.encode('$login:$nome:${DateTime.now().millisecondsSinceEpoch}'));
  }

  static Future<void> stop() async {
    await _server?.close();
    _logger.info('ApiServer', 'Servidor parado');
  }
}
