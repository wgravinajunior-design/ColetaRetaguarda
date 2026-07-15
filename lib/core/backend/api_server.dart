import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:io';
import '../logging/app_logger.dart';
import '../../features/core/database/db_connection.dart';
import 'jwt_service.dart';

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

  /// Valida JWT token do header Authorization
  static Map<String, dynamic>? _validateBearerToken(shelf.Request request) {
    final authHeader = request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7);
    return JwtService.validateToken(token);
  }

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

      final token = JwtService.generateToken(1, nome, perfil);
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
    // Valida JWT
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

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
    // Valida JWT
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

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
    // Valida JWT
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

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
    // Valida JWT
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

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

  static Future<shelf.Response> _listMotoristas(shelf.Request request) async {
    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
            'PES_LONGITUDE, PES_STATUS FROM TB_PESSOA WHERE PES_TIPO_PESSOA = \'M\' '
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
          'status': row['PES_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
        });
      }

      await query.close();

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar motoristas: $e');
    }
  }

  static Future<shelf.Response> _createMotorista(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'INSERT INTO TB_PESSOA (PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
          'PES_LONGITUDE, PES_STATUS, PES_TIPO_PESSOA) VALUES (?, ?, ?, ?, ?, ?)';

      query.Params.ByName('PES_RSOCIAL_NOME').AsString = data['nome'] ?? '';
      query.Params.ByName('PES_ENDERECO').AsString = data['endereco'] ?? '';
      query.Params.ByName('PES_LATITUDE').AsFloat = data['latitude'] ?? 0.0;
      query.Params.ByName('PES_LONGITUDE').AsFloat = data['longitude'] ?? 0.0;
      query.Params.ByName('PES_STATUS').AsString = 'A';
      query.Params.ByName('PES_TIPO_PESSOA').AsString = 'M';

      query.Execute();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': query.LastInsertId}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar motorista: $e');
    }
  }

  static Future<shelf.Response> _updateMotorista(
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
          'PES_ENDERECO = ?, PES_LATITUDE = ?, PES_LONGITUDE = ? '
          'WHERE PES_ID = ? AND PES_TIPO_PESSOA = \'M\'';

      query.Params.ByName('PES_RSOCIAL_NOME').AsString = data['nome'] ?? '';
      query.Params.ByName('PES_ENDERECO').AsString = data['endereco'] ?? '';
      query.Params.ByName('PES_LATITUDE').AsFloat = data['latitude'] ?? 0.0;
      query.Params.ByName('PES_LONGITUDE').AsFloat = data['longitude'] ?? 0.0;
      query.Params.ByName('PES_ID').AsInteger = pesId;

      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar motorista: $e');
    }
  }

  static Future<shelf.Response> _deleteMotorista(
      shelf.Request request, String id) async {
    try {
      final pesId = int.tryParse(id) ?? 0;
      if (pesId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ? AND PES_TIPO_PESSOA = \'M\'';
      query.Params.ByName('PES_ID').AsInteger = pesId;
      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar motorista: $e');
    }
  }

  // ============ VEICULOS ============

  static Future<shelf.Response> _listVeiculos(shelf.Request request) async {
    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT VEC_ID, VEC_PLACA, VEC_DESCRICAO, VEC_STATUS '
            'FROM TB_VEICULO ORDER BY VEC_PLACA',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['VEC_ID'],
          'placa': row['VEC_PLACA'],
          'descricao': row['VEC_DESCRICAO'] ?? '',
          'status': row['VEC_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
        });
      }

      await query.close();

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar veículos: $e');
    }
  }

  static Future<shelf.Response> _createVeiculo(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'INSERT INTO TB_VEICULO (VEC_PLACA, VEC_DESCRICAO, VEC_STATUS) VALUES (?, ?, ?)';

      query.Params.ByName('VEC_PLACA').AsString = data['placa'] ?? '';
      query.Params.ByName('VEC_DESCRICAO').AsString = data['descricao'] ?? '';
      query.Params.ByName('VEC_STATUS').AsString = 'A';

      query.Execute();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': query.LastInsertId}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar veículo: $e');
    }
  }

  static Future<shelf.Response> _updateVeiculo(
      shelf.Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final vecId = int.tryParse(id) ?? 0;

      if (vecId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL = 'UPDATE TB_VEICULO SET VEC_PLACA = ?, VEC_DESCRICAO = ? '
          'WHERE VEC_ID = ?';

      query.Params.ByName('VEC_PLACA').AsString = data['placa'] ?? '';
      query.Params.ByName('VEC_DESCRICAO').AsString = data['descricao'] ?? '';
      query.Params.ByName('VEC_ID').AsInteger = vecId;

      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar veículo: $e');
    }
  }

  static Future<shelf.Response> _deleteVeiculo(
      shelf.Request request, String id) async {
    try {
      final vecId = int.tryParse(id) ?? 0;
      if (vecId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL = 'UPDATE TB_VEICULO SET VEC_STATUS = \'I\' WHERE VEC_ID = ?';
      query.Params.ByName('VEC_ID').AsInteger = vecId;
      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar veículo: $e');
    }
  }

  // ============ ROTAS ============

  static Future<shelf.Response> _listRotas(shelf.Request request) async {
    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT ROT_ID, ROT_DESCRICAO, ROT_KM, ROT_STATUS '
            'FROM TB_ROTA ORDER BY ROT_DESCRICAO',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['ROT_ID'],
          'descricao': row['ROT_DESCRICAO'],
          'km': row['ROT_KM'] ?? 0.0,
          'status': row['ROT_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
        });
      }

      await query.close();

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar rotas: $e');
    }
  }

  static Future<shelf.Response> _createRota(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'INSERT INTO TB_ROTA (ROT_DESCRICAO, ROT_KM, ROT_STATUS) VALUES (?, ?, ?)';

      query.Params.ByName('ROT_DESCRICAO').AsString = data['descricao'] ?? '';
      query.Params.ByName('ROT_KM').AsFloat = data['km'] ?? 0.0;
      query.Params.ByName('ROT_STATUS').AsString = 'A';

      query.Execute();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': query.LastInsertId}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar rota: $e');
    }
  }

  static Future<shelf.Response> _updateRota(
      shelf.Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rotId = int.tryParse(id) ?? 0;

      if (rotId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL =
          'UPDATE TB_ROTA SET ROT_DESCRICAO = ?, ROT_KM = ? WHERE ROT_ID = ?';

      query.Params.ByName('ROT_DESCRICAO').AsString = data['descricao'] ?? '';
      query.Params.ByName('ROT_KM').AsFloat = data['km'] ?? 0.0;
      query.Params.ByName('ROT_ID').AsInteger = rotId;

      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar rota: $e');
    }
  }

  static Future<shelf.Response> _deleteRota(
      shelf.Request request, String id) async {
    try {
      final rotId = int.tryParse(id) ?? 0;
      if (rotId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      query.SQL = 'UPDATE TB_ROTA SET ROT_STATUS = \'I\' WHERE ROT_ID = ?';
      query.Params.ByName('ROT_ID').AsInteger = rotId;
      query.Execute();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar rota: $e');
    }
  }

  // ============ HELPERS ============

  static shelf.Response _errorResponse(int statusCode, String message) {
    return shelf.Response(statusCode,
        body: jsonEncode({'error': message, 'success': false}),
        headers: {'Content-Type': 'application/json'});
  }

  static shelf.Response _notImplemented() {
    return _errorResponse(501, 'Endpoint não implementado ainda');
  }

  static Future<void> stop() async {
    await _server?.close();
    _logger.info('ApiServer', 'Servidor parado');
  }
}
