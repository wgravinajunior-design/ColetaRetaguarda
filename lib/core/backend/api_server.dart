import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';
import '../logging/app_logger.dart';
import '../../features/core/database/db_connection.dart';
import 'jwt_service.dart';
import 'file_storage_service.dart';

/// Servidor HTTP integrado para sincronização mobile ↔ desktop
/// Roda em isolate separado para não bloquear UI
class ApiServer {
  static const int DEFAULT_PORT = 8080;
  static late AppLogger _logger;
  static HttpServer? _server;

  // Rate limiting: IP → {timestamp, tentativas}
  static final Map<String, _RateLimit> _rateLimits = {};
  static const int _maxAttempts = 5;
  static const Duration _blockDuration = Duration(minutes: 15);
  static const Duration _resetDuration = Duration(minutes: 1);

  // Cache: URL → {body, timestamp}
  static final Map<String, _CacheEntry> _responseCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

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
        ..delete('/coleta/rotas/<id>', _deleteRota)
        ..get('/coleta/paradas', _listParadas)
        ..post('/coleta/paradas', _createParada)
        ..put('/coleta/paradas/<id>', _updateParada)
        ..post('/coleta/paradas/<id>/foto', _uploadFotoParada);

      // Middleware (caching, logging, CORS, rate limiting, compression)
      final handler = shelf.Pipeline()
          .addMiddleware(_rateLimitMiddleware)
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_cacheMiddleware)
          .addMiddleware(_compressionMiddleware)
          .addMiddleware(_corsMiddleware)
          .addHandler(router);

      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _logger.info('ApiServer', 'Servidor iniciado em http://0.0.0.0:$port');
    } catch (e) {
      _logger.error('ApiServer', 'Erro ao iniciar servidor: $e');
      rethrow;
    }
  }

  /// Middleware Rate Limiting por IP
  static shelf.Middleware _rateLimitMiddleware = (innerHandler) {
    return (request) async {
      final ip = request.headers['x-forwarded-for'] ?? 'unknown';
      final rateLimit = _rateLimits.putIfAbsent(ip, () => _RateLimit());

      // Verifica se IP está bloqueado
      if (rateLimit.isBlocked()) {
        return shelf.Response(429,
            body: jsonEncode({
              'error': 'Muitas tentativas. Tente novamente em 15 minutos.',
              'success': false
            }),
            headers: {'Content-Type': 'application/json'});
      }

      // Reset se passou tempo suficiente
      if (rateLimit.shouldReset()) {
        rateLimit.attempts = 0;
        rateLimit.firstAttempt = DateTime.now();
      }

      rateLimit.attempts++;

      // Bloqueia se ultrapassou limite
      if (rateLimit.attempts > _maxAttempts) {
        rateLimit.blockedUntil = DateTime.now().add(_blockDuration);
        _logger.warning('ApiServer', 'IP bloqueado por rate limit: $ip');
        return shelf.Response(429,
            body: jsonEncode({
              'error': 'Muitas tentativas. Tente novamente mais tarde.',
              'success': false
            }),
            headers: {'Content-Type': 'application/json'});
      }

      return await innerHandler(request);
    };
  };

  /// Middleware Cache para GET requests
  static shelf.Middleware _cacheMiddleware = (innerHandler) {
    return (request) async {
      // Só cacheia GET requests
      if (request.method != 'GET') {
        return await innerHandler(request);
      }

      final cacheKey = request.url.toString();
      final cached = _responseCache[cacheKey];

      // Retorna do cache se ainda é válido
      if (cached != null && !cached.isExpired()) {
        _logger.info('ApiServer', 'Cache hit: $cacheKey');
        return shelf.Response.ok(cached.body,
            headers: {
              'Content-Type': 'application/json',
              'X-Cache': 'HIT',
            });
      }

      final response = await innerHandler(request);

      // Cacheia se sucesso (200-299)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final body = await response.readAsString();
          _responseCache[cacheKey] = _CacheEntry(body);
          return shelf.Response(response.statusCode,
              body: body,
              headers: {
                ...response.headers,
                'X-Cache': 'MISS',
              });
        } catch (e) {
          return response;
        }
      }

      return response;
    };
  };

  /// Middleware Compressão Gzip para reduzir tráfego
  static shelf.Middleware _compressionMiddleware = (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);

      // Só comprime JSON e texto
      final contentType = response.headers['content-type'] ?? '';
      final shouldCompress = contentType.contains('json') || contentType.contains('text');

      if (!shouldCompress || response.contentLength == null || response.contentLength! < 1024) {
        return response;
      }

      // Verifica se cliente aceita gzip
      final acceptEncoding = request.headers['accept-encoding'] ?? '';
      if (!acceptEncoding.contains('gzip')) {
        return response;
      }

      try {
        final body = await response.read().toList();
        final compressed = gzip.encode(body.expand((bytes) => bytes).toList());
        return response.change(
          body: Stream.value(compressed),
          headers: {'Content-Encoding': 'gzip'},
        );
      } catch (e) {
        return response; // Se falhar, retorna sem compressão
      }
    };
  };

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

      await query.openCursor(
        sql: 'INSERT INTO TB_PESSOA (PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
            'PES_LONGITUDE, PES_VOLUME_MEDIO, PES_HR_COLETA, PES_KM, PES_STATUS, '
            'PES_FORNECEDOR, PES_TIPO_PESSOA) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
            'RETURNING PES_ID',
        parameters: [
          data['nome'] ?? '',
          data['endereco'] ?? '',
          data['latitude'] ?? 0.0,
          data['longitude'] ?? 0.0,
          data['volume_medio'] ?? 0.0,
          data['hr_coleta'] ?? '',
          data['km'] ?? 0.0,
          'A',
          'S',
          'P',
        ],
      );

      var id = 0;
      await for (var row in query.rows()) {
        id = row['PES_ID'] ?? 0;
        break;
      }
      await query.close();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': id}),
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

      await query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_RSOCIAL_NOME = ?, '
            'PES_ENDERECO = ?, PES_LATITUDE = ?, PES_LONGITUDE = ?, '
            'PES_VOLUME_MEDIO = ?, PES_HR_COLETA = ?, PES_KM = ? '
            'WHERE PES_ID = ?',
        parameters: [
          data['nome'] ?? '',
          data['endereco'] ?? '',
          data['latitude'] ?? 0.0,
          data['longitude'] ?? 0.0,
          data['volume_medio'] ?? 0.0,
          data['hr_coleta'] ?? '',
          data['km'] ?? 0.0,
          pesId,
        ],
      );

      await query.close();

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

      await query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ?',
        parameters: [pesId],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar pessoa: $e');
    }
  }

  // ============ MOTORISTAS ============

  static Future<shelf.Response> _listMotoristas(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, '
            'PES_CNPJ_CPF, PES_IE_RG, PES_TELEFONE, PES_CELULAR, '
            'PES_EMAIL, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, '
            'PES_BAIRRO, PES_CIDADE, PES_CEP, PES_CNH, PES_CNH_VALIDADE, '
            'PES_STATUS FROM TB_PESSOA WHERE PES_TIPO_PESSOA = \'M\' AND '
            'PES_STATUS = \'A\' ORDER BY PES_RSOCIAL_NOME',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['PES_ID'],
          'nome': row['PES_RSOCIAL_NOME'],
          'apelido': row['PES_FANTASIA_APELIDO'] ?? '',
          'cpf': row['PES_CNPJ_CPF'] ?? '',
          'rg': row['PES_IE_RG'] ?? '',
          'telefone': row['PES_TELEFONE'],
          'celular': row['PES_CELULAR'],
          'email': row['PES_EMAIL'],
          'endereco': row['PES_ENDERECO'],
          'numero': row['PES_NUMERO'],
          'complemento': row['PES_COMPLEMENTO'],
          'bairro': row['PES_BAIRRO'],
          'cidade': row['PES_CIDADE'],
          'cep': row['PES_CEP'],
          'cnh': row['PES_CNH'],
          'cnh_validade': row['PES_CNH_VALIDADE'],
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
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'INSERT INTO TB_PESSOA (PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, '
            'PES_CNPJ_CPF, PES_IE_RG, PES_TELEFONE, PES_CELULAR, PES_EMAIL, '
            'PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, '
            'PES_CIDADE, PES_CEP, PES_CNH, PES_CNH_VALIDADE, '
            'PES_STATUS, PES_TIPO_PESSOA) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '
            '?, ?, ?, ?, ?, ?, ?, ?) RETURNING PES_ID',
        parameters: [
          data['nome'] ?? '',
          data['apelido'],
          data['cpf'] ?? '',
          data['rg'] ?? '',
          data['telefone'],
          data['celular'],
          data['email'],
          data['endereco'],
          data['numero'],
          data['complemento'],
          data['bairro'],
          data['cidade'],
          data['cep'],
          data['cnh'],
          data['cnh_validade'],
          'A',
          'M',
        ],
      );

      var id = 0;
      await for (var row in query.rows()) {
        id = row['PES_ID'] ?? 0;
        break;
      }
      await query.close();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': id}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar motorista: $e');
    }
  }

  static Future<shelf.Response> _updateMotorista(
      shelf.Request request, String id) async {
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

      await query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_RSOCIAL_NOME = ?, '
            'PES_FANTASIA_APELIDO = ?, PES_TELEFONE = ?, PES_CELULAR = ?, '
            'PES_EMAIL = ?, PES_ENDERECO = ?, PES_NUMERO = ?, '
            'PES_COMPLEMENTO = ?, PES_BAIRRO = ?, PES_CIDADE = ?, '
            'PES_CEP = ?, PES_CNH = ?, PES_CNH_VALIDADE = ? '
            'WHERE PES_ID = ? AND PES_TIPO_PESSOA = \'M\'',
        parameters: [
          data['nome'] ?? '',
          data['apelido'],
          data['telefone'],
          data['celular'],
          data['email'],
          data['endereco'],
          data['numero'],
          data['complemento'],
          data['bairro'],
          data['cidade'],
          data['cep'],
          data['cnh'],
          data['cnh_validade'],
          pesId,
        ],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar motorista: $e');
    }
  }

  static Future<shelf.Response> _deleteMotorista(
      shelf.Request request, String id) async {
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

      await query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ? AND '
            'PES_TIPO_PESSOA = \'M\'',
        parameters: [pesId],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar motorista: $e');
    }
  }

  // ============ VEICULOS ============

  static Future<shelf.Response> _listVeiculos(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT VEI_ID, VEI_PLACA, VEI_MARCA, VEI_MODELO, VEI_COR, '
            'VEI_ANO, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, VEI_STATUS '
            'FROM TB_VEICULO WHERE VEI_STATUS = \'A\' '
            'ORDER BY VEI_PLACA',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['VEI_ID'],
          'placa': row['VEI_PLACA'],
          'marca': row['VEI_MARCA'] ?? '',
          'modelo': row['VEI_MODELO'] ?? '',
          'cor': row['VEI_COR'] ?? '',
          'ano': row['VEI_ANO'] ?? '',
          'tipo': row['VEI_TIPO'] ?? 'C',
          'renavam': row['VEI_RENAVAM'] ?? '',
          'chassi': row['VEI_CHASSI'],
          'status': row['VEI_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
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
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'INSERT INTO TB_VEICULO (VEI_PLACA, VEI_MARCA, VEI_MODELO, '
            'VEI_COR, VEI_ANO, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, '
            'VEI_STATUS) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
            'RETURNING VEI_ID',
        parameters: [
          data['placa'] ?? '',
          data['marca'] ?? '',
          data['modelo'] ?? '',
          data['cor'] ?? '',
          data['ano'] ?? '',
          data['tipo'] ?? 'C',
          data['renavam'] ?? '',
          data['chassi'],
          'A',
        ],
      );

      var id = 0;
      await for (var row in query.rows()) {
        id = row['VEI_ID'] ?? 0;
        break;
      }
      await query.close();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': id}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar veículo: $e');
    }
  }

  static Future<shelf.Response> _updateVeiculo(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final veiId = int.tryParse(id) ?? 0;

      if (veiId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_VEICULO SET VEI_PLACA = ?, VEI_MARCA = ?, '
            'VEI_MODELO = ?, VEI_COR = ?, VEI_ANO = ?, VEI_TIPO = ?, '
            'VEI_RENAVAM = ?, VEI_CHASSI = ? WHERE VEI_ID = ?',
        parameters: [
          data['placa'] ?? '',
          data['marca'] ?? '',
          data['modelo'] ?? '',
          data['cor'] ?? '',
          data['ano'] ?? '',
          data['tipo'] ?? 'C',
          data['renavam'] ?? '',
          data['chassi'],
          veiId,
        ],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar veículo: $e');
    }
  }

  static Future<shelf.Response> _deleteVeiculo(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final veiId = int.tryParse(id) ?? 0;
      if (veiId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_VEICULO SET VEI_STATUS = \'I\' WHERE VEI_ID = ?',
        parameters: [veiId],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar veículo: $e');
    }
  }

  // ============ ROTAS ============

  static Future<shelf.Response> _listRotas(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final db = await DbConnection().db;
      final query = db.query();
      await query.openCursor(
        sql: 'SELECT ROT_ID, ROT_DESCRICAO, ROT_REGIAO, ROT_MOTORISTA_ID, '
            'ROT_VEICULO_ID, ROT_STATUS, ROT_DATA_PREVISTA, ROT_DATA_INICIO, '
            'ROT_DATA_FIM, ROT_PARADAS, ROT_KM_ESTIMADO, ROT_KM_REALIZADO '
            'FROM TB_ROTA WHERE ROT_STATUS IN (\'A\', \'P\') '
            'ORDER BY ROT_DATA_PREVISTA DESC',
      );

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['ROT_ID'],
          'descricao': row['ROT_DESCRICAO'],
          'regiao': row['ROT_REGIAO'],
          'motorista_id': row['ROT_MOTORISTA_ID'],
          'veiculo_id': row['ROT_VEICULO_ID'],
          'status': row['ROT_STATUS'],
          'data_prevista': row['ROT_DATA_PREVISTA'],
          'data_inicio': row['ROT_DATA_INICIO'],
          'data_fim': row['ROT_DATA_FIM'],
          'paradas': row['ROT_PARADAS'] ?? 0,
          'km_estimado': row['ROT_KM_ESTIMADO'] ?? 0.0,
          'km_realizado': row['ROT_KM_REALIZADO'] ?? 0.0,
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
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'INSERT INTO TB_ROTA (ROT_DESCRICAO, ROT_REGIAO, '
            'ROT_MOTORISTA_ID, ROT_VEICULO_ID, ROT_STATUS, '
            'ROT_DATA_PREVISTA, ROT_PARADAS, ROT_KM_ESTIMADO) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING ROT_ID',
        parameters: [
          data['descricao'] ?? '',
          data['regiao'],
          data['motorista_id'],
          data['veiculo_id'],
          'A',
          data['data_prevista'],
          data['paradas'] ?? 0,
          data['km_estimado'] ?? 0.0,
        ],
      );

      var id = 0;
      await for (var row in query.rows()) {
        id = row['ROT_ID'] ?? 0;
        break;
      }
      await query.close();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': id}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar rota: $e');
    }
  }

  static Future<shelf.Response> _updateRota(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rotId = int.tryParse(id) ?? 0;

      if (rotId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_ROTA SET ROT_DESCRICAO = ?, ROT_REGIAO = ?, '
            'ROT_MOTORISTA_ID = ?, ROT_VEICULO_ID = ?, ROT_STATUS = ?, '
            'ROT_DATA_INICIO = ?, ROT_DATA_FIM = ?, '
            'ROT_KM_REALIZADO = ? WHERE ROT_ID = ?',
        parameters: [
          data['descricao'] ?? '',
          data['regiao'],
          data['motorista_id'],
          data['veiculo_id'],
          data['status'] ?? 'A',
          data['data_inicio'],
          data['data_fim'],
          data['km_realizado'] ?? 0.0,
          rotId,
        ],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar rota: $e');
    }
  }

  static Future<shelf.Response> _deleteRota(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final rotId = int.tryParse(id) ?? 0;
      if (rotId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_ROTA SET ROT_STATUS = \'I\' WHERE ROT_ID = ?',
        parameters: [rotId],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar rota: $e');
    }
  }

  // ============ PARADAS/COLETA ============

  static Future<shelf.Response> _listParadas(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final rotaId = request.url.queryParameters['rota_id'];
      final status = request.url.queryParameters['status'];

      if (rotaId == null) {
        return _errorResponse(400, 'Parâmetro rota_id obrigatório');
      }

      final db = await DbConnection().db;
      final query = db.query();

      String sql = 'SELECT PAR_ID, PAR_ROTA_ID, PAR_PESSOA_ID, '
          'PAR_PESSOA_NOME, PAR_CNPJ_CPF, PAR_ENDERECO, '
          'PAR_LATITUDE, PAR_LONGITUDE, PAR_STATUS, '
          'PAR_TEMPERATURA, PAR_VOLUME, PAR_JUSTIFICATIVA, '
          'PAR_GPS_LATITUDE, PAR_GPS_LONGITUDE, '
          'PAR_HORARIO_CHEGADA, PAR_HORARIO_SAIDA, '
          'PAR_FOTO_PATH, PAR_ASSINATURA_BASE64 '
          'FROM TB_PARADA WHERE PAR_ROTA_ID = ?';

      final params = <dynamic>[int.tryParse(rotaId) ?? 0];

      if (status != null && status.isNotEmpty) {
        sql += ' AND PAR_STATUS = ?';
        params.add(status);
      }

      sql += ' ORDER BY PAR_ID';

      await query.openCursor(sql: sql, parameters: params);

      final items = <Map<String, dynamic>>[];
      await for (var row in query.rows()) {
        items.add({
          'id': row['PAR_ID'],
          'rota_id': row['PAR_ROTA_ID'],
          'pessoa_id': row['PAR_PESSOA_ID'],
          'pessoa_nome': row['PAR_PESSOA_NOME'],
          'cnpj_cpf': row['PAR_CNPJ_CPF'],
          'endereco': row['PAR_ENDERECO'],
          'latitude': row['PAR_LATITUDE'] ?? 0.0,
          'longitude': row['PAR_LONGITUDE'] ?? 0.0,
          'status': row['PAR_STATUS'] ?? 'P',
          'temperatura': row['PAR_TEMPERATURA'],
          'volume': row['PAR_VOLUME'],
          'justificativa': row['PAR_JUSTIFICATIVA'],
          'gps_captura_latitude': row['PAR_GPS_LATITUDE'],
          'gps_captura_longitude': row['PAR_GPS_LONGITUDE'],
          'horario_chegada': row['PAR_HORARIO_CHEGADA'],
          'horario_saida': row['PAR_HORARIO_SAIDA'],
          'foto_path': row['PAR_FOTO_PATH'],
          'assinatura_base64': row['PAR_ASSINATURA_BASE64'],
        });
      }

      await query.close();

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar paradas: $e');
    }
  }

  static Future<shelf.Response> _createParada(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'INSERT INTO TB_PARADA (PAR_ROTA_ID, PAR_PESSOA_ID, '
            'PAR_PESSOA_NOME, PAR_CNPJ_CPF, PAR_ENDERECO, '
            'PAR_LATITUDE, PAR_LONGITUDE, PAR_STATUS, '
            'PAR_TEMPERATURA, PAR_VOLUME, PAR_GPS_LATITUDE, '
            'PAR_GPS_LONGITUDE, PAR_HORARIO_CHEGADA) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
            'RETURNING PAR_ID',
        parameters: [
          data['rota_id'],
          data['pessoa_id'],
          data['pessoa_nome'],
          data['cnpj_cpf'],
          data['endereco'],
          data['latitude'] ?? 0.0,
          data['longitude'] ?? 0.0,
          data['status'] ?? 'P',
          data['temperatura'],
          data['volume'],
          data['gps_captura_latitude'] ?? 0.0,
          data['gps_captura_longitude'] ?? 0.0,
          data['horario_chegada'],
        ],
      );

      var id = 0;
      await for (var row in query.rows()) {
        id = row['PAR_ID'] ?? 0;
        break;
      }
      await query.close();

      return shelf.Response(201,
          body: jsonEncode({'success': true, 'id': id}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao criar parada: $e');
    }
  }

  static Future<shelf.Response> _updateParada(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final parId = int.tryParse(id) ?? 0;

      if (parId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_PARADA SET PAR_STATUS = ?, PAR_TEMPERATURA = ?, '
            'PAR_VOLUME = ?, PAR_JUSTIFICATIVA = ?, '
            'PAR_GPS_LATITUDE = ?, PAR_GPS_LONGITUDE = ?, '
            'PAR_HORARIO_CHEGADA = ?, PAR_HORARIO_SAIDA = ?, '
            'PAR_ASSINATURA_BASE64 = ? WHERE PAR_ID = ?',
        parameters: [
          data['status'] ?? 'P',
          data['temperatura'],
          data['volume'],
          data['justificativa'],
          data['gps_captura_latitude'],
          data['gps_captura_longitude'],
          data['horario_chegada'],
          data['horario_saida'],
          data['assinatura_base64'],
          parId,
        ],
      );

      await query.close();

      return shelf.Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar parada: $e');
    }
  }

  static Future<shelf.Response> _uploadFotoParada(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final parId = int.tryParse(id) ?? 0;
      if (parId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      // Parse multipart/form-data
      final parts = <String, List<int>>{};
      await for (final part in request.parts) {
        final bytes = await part.readBytes();
        parts[part.name] = bytes;
      }

      // Validar arquivo
      if (!parts.containsKey('file') || parts['file']!.isEmpty) {
        return _errorResponse(400, 'Arquivo não fornecido');
      }

      final fileBytes = parts['file']!;

      // Validar tamanho (<10MB)
      if (fileBytes.length > 10 * 1024 * 1024) {
        return _errorResponse(400, 'Arquivo excede 10MB');
      }

      // Validar MIME (JPEG/PNG)
      if (!FileStorageService.isValidImage(fileBytes)) {
        return _errorResponse(400, 'Arquivo deve ser JPEG ou PNG');
      }

      // Salvar arquivo
      final fotoPath = await FileStorageService.saveFoto(parId, fileBytes);
      if (fotoPath == null) {
        return _errorResponse(500, 'Erro ao salvar arquivo');
      }

      // Atualizar BD: TB_PARADA.PAR_FOTO_PATH
      final db = await DbConnection().db;
      final query = db.query();

      await query.openCursor(
        sql: 'UPDATE TB_PARADA SET PAR_FOTO_PATH = ? WHERE PAR_ID = ?',
        parameters: [fotoPath, parId],
      );

      await query.close();

      _logger.info('ApiServer', 'Foto salva para parada $parId: $fotoPath');

      return shelf.Response.ok(
          jsonEncode({
            'success': true,
            'url': '/uploads/$fotoPath',
            'path': fotoPath,
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      _logger.error('ApiServer', 'Erro ao upload foto: $e');
      return _errorResponse(500, 'Erro ao upload de foto: $e');
    }
  }

  // ============ HELPERS ============

  static shelf.Response _errorResponse(int statusCode, String message) {
    return shelf.Response(statusCode,
        body: jsonEncode({'error': message, 'success': false}),
        headers: {'Content-Type': 'application/json'});
  }

  static Future<void> stop() async {
    await _server?.close();
    _logger.info('ApiServer', 'Servidor parado');
  }
}

// ============ RATE LIMITING ============

class _RateLimit {
  int attempts = 0;
  DateTime firstAttempt = DateTime.now();
  DateTime? blockedUntil;

  bool isBlocked() {
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil!)) {
      return true;
    }
    blockedUntil = null;
    return false;
  }

  bool shouldReset() {
    return DateTime.now().difference(firstAttempt) > ApiServer._resetDuration;
  }
}

// ============ CACHING ============

class _CacheEntry {
  final String body;
  final DateTime timestamp = DateTime.now();

  _CacheEntry(this.body);

  bool isExpired() {
    return DateTime.now().difference(timestamp) > ApiServer._cacheDuration;
  }
}
