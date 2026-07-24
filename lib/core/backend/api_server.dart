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
        ..get('/ping', _health) // alias usado pelo teste de conexão do app mobile
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
        ..post('/coleta/paradas/<id>/foto', _uploadFotoParada)
        // ── Endpoints do app mobile (contrato: {success, data} + tabelas reais
        //    do ERP COLETAS_ROTA/COLETAS_DETALHE). Ver reconciliação fase 2/3.
        ..get('/coleta/produtores', _listProdutores)
        ..get('/coleta/colaboradores', _listColaboradores)
        ..get('/coleta/resfriadores', _listResfriadores)
        ..get('/coleta/rotas/<id>/detalhes', _listRotaDetalhes)
        ..put('/coleta/detalhes/<id>', _updateDetalhe)
        ..post('/coleta/detalhes/<id>/foto', _uploadFotoParada)
        ..post('/coleta/sync', _syncBulk)
        ..delete('/auth/logout', _logout);

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final login = data['login'] as String?;
      final senha = data['senha'] as String?;

      if (login == null || senha == null) {
        return shelf.Response(400,
            body: jsonEncode({'error': 'Login e senha obrigatórios'}),
            headers: {'Content-Type': 'application/json'});
      }

      final db = await DbConnection().db;
      var found = false;
      String nome = '';
      String perfil = 'OPERADOR';

      await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT USU_ID, USU_NOME, USU_PERFIL FROM TB_USUARIO '
              'WHERE USU_LOGIN = ? AND USU_SENHA = ? AND USU_STATUS = \'A\'',
          parameters: [login, senha],
        );
        await for (var row in query.rows()) {
          found = true;
          nome = row['USU_NOME'];
          perfil = row['USU_PERFIL'] ?? 'OPERADOR';
          break;
        }
      });

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
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
              'PES_LONGITUDE, PES_VOLUME_MEDIO, PES_HR_COLETA, PES_KM, '
              'PES_STATUS FROM TB_PESSOA WHERE PES_FORNECEDOR = \'S\' '
              'ORDER BY PES_RSOCIAL_NOME',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
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
        return list;
      });

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar pessoas: $e');
    }
  }

  /// GET /coleta/produtores — contrato do app mobile.
  /// Devolve {success, data:[...]} com os nomes de campo que o mobile espera.
  /// Reusa a query de fornecedores (TB_PESSOA, PES_FORNECEDOR='S') do _listPessoas.
  static Future<shelf.Response> _listProdutores(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_ENDERECO, PES_LATITUDE, '
              'PES_LONGITUDE, PES_VOLUME_MEDIO, PES_HR_COLETA, PES_KM, '
              'PES_ID_RESFRIADOR, PES_STATUS FROM TB_PESSOA '
              'WHERE PES_FORNECEDOR = \'S\' ORDER BY PES_RSOCIAL_NOME',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['PES_ID'],
            'nome': row['PES_RSOCIAL_NOME'],
            'endereco': row['PES_ENDERECO'] ?? '',
            'latitude': row['PES_LATITUDE'] ?? 0.0,
            'longitude': row['PES_LONGITUDE'] ?? 0.0,
            'volume_medio_diario': row['PES_VOLUME_MEDIO'] ?? 0.0,
            'horario_coleta_previsto': row['PES_HR_COLETA'] ?? '',
            'km_ate_tanque_principal': row['PES_KM'] ?? 0.0,
            'id_resfriador': row['PES_ID_RESFRIADOR'],
            'status': row['PES_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
          });
        }
        return list;
      });

      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar produtores: $e');
    }
  }

  /// GET /coleta/colaboradores — contrato do app mobile.
  /// Colaboradores do ERP são TB_PESSOA marcadas com PES_COLABORADOR='S'.
  /// funcao_cargo/permissoes não têm coluna dedicada confirmada em TB_PESSOA —
  /// vão com default (o app aceita).
  static Future<shelf.Response> _listColaboradores(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }
    try {
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_CNPJ_CPF, PES_STATUS '
              'FROM TB_PESSOA WHERE PES_COLABORADOR = \'S\' '
              'ORDER BY PES_RSOCIAL_NOME',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['PES_ID'],
            'nome': row['PES_RSOCIAL_NOME'] ?? '',
            'cpf': row['PES_CNPJ_CPF'] ?? '',
            'funcao_cargo': '',
            'permissoes': 'Operador',
            'status': row['PES_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
          });
        }
        return list;
      });
      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar colaboradores: $e');
    }
  }

  /// GET /coleta/resfriadores — contrato do app mobile.
  /// Subconjunto seguro de TB_RESFRIADOR (colunas confirmadas em uso pelo
  /// firebird_service); demais campos ficam com default no app.
  static Future<shelf.Response> _listResfriadores(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }
    try {
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT RES_ID, RES_NUMERO_ID, RES_MARCA_MODELO, RES_STATUS '
              'FROM TB_RESFRIADOR '
              "WHERE (RES_STATUS IS NULL OR RES_STATUS <> 'INATIVO') "
              'ORDER BY RES_NUMERO_ID',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['RES_ID'],
            'numero_identificador': row['RES_NUMERO_ID'] ?? '',
            'marca_modelo': row['RES_MARCA_MODELO'] ?? '',
            'ano_fabricacao': 0,
            'capacidade_litros': 0.0,
            'ultima_manutencao': null,
            'status': (row['RES_STATUS'] == null || row['RES_STATUS'] == 'INATIVO')
                ? 'INATIVO'
                : 'ATIVO',
          });
        }
        return list;
      });
      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar resfriadores: $e');
    }
  }

  /// GET /coleta/rotas/&lt;id&gt;/detalhes — paradas de uma rota (COLETAS_DETALHE).
  /// Espelha o SELECT de coletas do firebird_service; os nomes de coluna já
  /// coincidem com os campos que o mobile espera.
  static Future<shelf.Response> _listRotaDetalhes(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }
    final rotaId = int.tryParse(id) ?? 0;
    if (rotaId == 0) return _errorResponse(400, 'ID inválido');
    try {
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT ID, ID_COLETA_ROTA, ID_PRODUTOR, ORDEM_VISITA, STATUS, '
              'VOLUME_COLETADO_LITROS, TEMPERATURA_LEITE_C, MOTIVO_ADIAMENTO, '
              'FOTO_CAMINHO, DATA_HORA_REGISTRO '
              'FROM COLETAS_DETALHE WHERE ID_COLETA_ROTA = ? ORDER BY ORDEM_VISITA',
          parameters: [rotaId],
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['ID'],
            'id_coleta_rota': row['ID_COLETA_ROTA'],
            'id_produtor': row['ID_PRODUTOR'],
            'ordem_visita': row['ORDEM_VISITA'] ?? 0,
            'data_hora_registro': row['DATA_HORA_REGISTRO'],
            'volume_coletado_litros': row['VOLUME_COLETADO_LITROS'] ?? 0.0,
            'temperatura_leite_c': row['TEMPERATURA_LEITE_C'] ?? 0.0,
            'observacao': '',
            'motivo_adiamento': row['MOTIVO_ADIAMENTO'] ?? '',
            'status': row['STATUS'] ?? 'PENDENTE',
            'foto_caminho': row['FOTO_CAMINHO'],
          });
        }
        return list;
      });
      return shelf.Response.ok(
        jsonEncode({'success': true, 'data': items}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao listar detalhes da rota: $e');
    }
  }

  /// PUT /coleta/detalhes/&lt;id&gt; — atualiza uma coleta (COLETAS_DETALHE).
  /// O app envia o status já no vocabulário do ERP (CONFIRMADO/RECUSADO/ADIADO/
  /// PENDENTE), gravado direto. COALESCE preserva o que não veio no payload.
  static Future<shelf.Response> _updateDetalhe(
      shelf.Request request, String id) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }
    final detId = int.tryParse(id) ?? 0;
    if (detId == 0) return _errorResponse(400, 'ID inválido');
    try {
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      // Só grava caminho de foto já gerenciado pelo servidor (uploads/...);
      // caminho local do device é ignorado — a foto sobe pelo endpoint /foto.
      final foto = data['foto_caminho'];
      final fotoServer =
          (foto is String && foto.startsWith('uploads/')) ? foto : null;
      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE COLETAS_DETALHE SET '
            'STATUS = COALESCE(?, STATUS), '
            'VOLUME_COLETADO_LITROS = COALESCE(?, VOLUME_COLETADO_LITROS), '
            'TEMPERATURA_LEITE_C = COALESCE(?, TEMPERATURA_LEITE_C), '
            'MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO), '
            'FOTO_CAMINHO = COALESCE(?, FOTO_CAMINHO), '
            'DATA_HORA_REGISTRO = COALESCE(?, DATA_HORA_REGISTRO) '
            'WHERE ID = ?',
        parameters: [
          data['status'],
          data['volume_coletado_litros'],
          data['temperatura_leite_c'],
          data['motivo_adiamento'],
          fotoServer,
          data['data_hora_registro'],
          detId,
        ],
      ));
      return shelf.Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro ao atualizar detalhe: $e');
    }
  }

  /// POST /coleta/sync — envio em lote do app (rotas + detalhes acumulados
  /// offline). Aplica status da rota e de cada detalhe em COLETAS_*.
  static Future<shelf.Response> _syncBulk(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }
    try {
      final body = await _readJsonBody(request);
      if (body == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final rotas = (body['rotas'] as List?) ?? const [];
      final db = await DbConnection().db;
      int aplicados = 0;

      for (final r in rotas) {
        final rota = r as Map<String, dynamic>;
        final rotaId = rota['id'];
        if (rotaId != null) {
          await _withCursor(db, (q) => q.openCursor(
            sql: 'UPDATE COLETAS_ROTA SET STATUS = COALESCE(?, STATUS), '
                'DATA_HORA_INICIO = COALESCE(?, DATA_HORA_INICIO), '
                'DATA_HORA_FIM = COALESCE(?, DATA_HORA_FIM) WHERE ID = ?',
            parameters: [
              rota['status'],
              rota['data_hora_inicio'],
              rota['data_hora_fim'],
              rotaId,
            ],
          ));
        }

        final detalhes = (rota['detalhes'] as List?) ?? const [];
        for (final d in detalhes) {
          final det = d as Map<String, dynamic>;
          final detId = det['id'];
          if (detId == null) continue;
          // Só aceita caminho de foto já gerenciado pelo servidor; um caminho
          // local do device (upload ainda não feito) é ignorado para não gravar
          // referência inválida — a foto sobe pelo endpoint /foto.
          final foto = det['foto_caminho'];
          final fotoServer =
              (foto is String && foto.startsWith('uploads/')) ? foto : null;
          await _withCursor(db, (q) => q.openCursor(
            sql: 'UPDATE COLETAS_DETALHE SET '
                'STATUS = COALESCE(?, STATUS), '
                'VOLUME_COLETADO_LITROS = COALESCE(?, VOLUME_COLETADO_LITROS), '
                'TEMPERATURA_LEITE_C = COALESCE(?, TEMPERATURA_LEITE_C), '
                'MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO), '
                'FOTO_CAMINHO = COALESCE(?, FOTO_CAMINHO), '
                'DATA_HORA_REGISTRO = COALESCE(?, DATA_HORA_REGISTRO) '
                'WHERE ID = ?',
            parameters: [
              det['status'],
              det['volume_coletado_litros'],
              det['temperatura_leite_c'],
              det['motivo_adiamento'],
              fotoServer,
              det['data_hora_registro'],
              detId,
            ],
          ));
          aplicados++;
        }
      }

      return shelf.Response.ok(
        jsonEncode({'success': true, 'aplicados': aplicados}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return _errorResponse(500, 'Erro no sync em lote: $e');
    }
  }

  /// DELETE /auth/logout — JWT é stateless; apenas confirma. O app limpa o
  /// token localmente.
  static Future<shelf.Response> _logout(shelf.Request request) async {
    return shelf.Response.ok(
      jsonEncode({'success': true}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<shelf.Response> _createPessoa(shelf.Request request) async {
    // Valida JWT
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }

      final db = await DbConnection().db;
      final id = await _withCursor(db, (query) async {
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
        var v = 0;
        await for (var row in query.rows()) {
          v = row['PES_ID'] ?? 0;
          break;
        }
        return v;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final pesId = int.tryParse(id) ?? 0;

      if (pesId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
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
      ));

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
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ?',
        parameters: [pesId],
      ));

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
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT PES_ID, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, '
              'PES_CNPJ_CPF, PES_IE_RG, PES_TELEFONE, PES_CELULAR, '
              'PES_EMAIL, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, '
              'PES_BAIRRO, PES_CIDADE, PES_CEP, PES_CNH, PES_CNH_VALIDADE, '
              'PES_STATUS FROM TB_PESSOA WHERE PES_TRANSPORTADOR = \'S\' AND '
              'PES_STATUS = \'A\' ORDER BY PES_RSOCIAL_NOME',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
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
        return list;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }

      final db = await DbConnection().db;
      final id = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'INSERT INTO TB_PESSOA (PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, '
              'PES_CNPJ_CPF, PES_IE_RG, PES_TELEFONE, PES_CELULAR, PES_EMAIL, '
              'PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, '
              'PES_CIDADE, PES_CEP, PES_CNH, PES_CNH_VALIDADE, '
              'PES_STATUS, PES_TRANSPORTADOR) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '
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
            'S', // PES_TRANSPORTADOR = 'S' (convenção do ERP para motorista)
          ],
        );
        var v = 0;
        await for (var row in query.rows()) {
          v = row['PES_ID'] ?? 0;
          break;
        }
        return v;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final pesId = int.tryParse(id) ?? 0;

      if (pesId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_RSOCIAL_NOME = ?, '
            'PES_FANTASIA_APELIDO = ?, PES_TELEFONE = ?, PES_CELULAR = ?, '
            'PES_EMAIL = ?, PES_ENDERECO = ?, PES_NUMERO = ?, '
            'PES_COMPLEMENTO = ?, PES_BAIRRO = ?, PES_CIDADE = ?, '
            'PES_CEP = ?, PES_CNH = ?, PES_CNH_VALIDADE = ? '
            'WHERE PES_ID = ? AND PES_TRANSPORTADOR = \'S\'',
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
      ));

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
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE TB_PESSOA SET PES_STATUS = \'I\' WHERE PES_ID = ? AND '
            'PES_TRANSPORTADOR = \'S\'',
        parameters: [pesId],
      ));

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
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT VEI_ID, VEI_PLACA, VEI_MARCA, VEI_MODELO, VEI_COR, '
              'VEI_ANO, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, VEI_STATUS '
              'FROM TB_VEICULO WHERE VEI_STATUS = \'A\' '
              'ORDER BY VEI_PLACA',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['VEI_ID'],
            'placa': row['VEI_PLACA'],
            'marca': row['VEI_MARCA'] ?? '',
            'modelo': row['VEI_MODELO'] ?? '',
            // Campo que o app mobile usa como rótulo do veículo (marca + modelo).
            'descricao': [row['VEI_MARCA'], row['VEI_MODELO']]
                .where((e) => e != null && '$e'.trim().isNotEmpty)
                .join(' ')
                .trim(),
            'cor': row['VEI_COR'] ?? '',
            'ano': row['VEI_ANO'] ?? '',
            'tipo': row['VEI_TIPO'] ?? 'C',
            'renavam': row['VEI_RENAVAM'] ?? '',
            'chassi': row['VEI_CHASSI'],
            'status': row['VEI_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
          });
        }
        return list;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }

      final db = await DbConnection().db;
      final id = await _withCursor(db, (query) async {
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
        var v = 0;
        await for (var row in query.rows()) {
          v = row['VEI_ID'] ?? 0;
          break;
        }
        return v;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final veiId = int.tryParse(id) ?? 0;

      if (veiId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
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
      ));

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
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE TB_VEICULO SET VEI_STATUS = \'I\' WHERE VEI_ID = ?',
        parameters: [veiId],
      ));

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
      // Tabela real do ERP (COLETAS_ROTA); nomes de coluna já batem com o mobile.
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        // FIRST 300: limita ao lote mais recente (evita baixar todo o histórico
        // a cada sync do app). Ordena por data desc, então as ativas/recentes vêm.
        await query.openCursor(
          sql: 'SELECT FIRST 300 ID, NOME, ID_MOTORISTA, ID_VEICULO, DATA_COLETA, '
              'DATA_HORA_INICIO, DATA_HORA_FIM, STATUS '
              'FROM COLETAS_ROTA ORDER BY DATA_COLETA DESC',
        );
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
            'id': row['ID'],
            'nome': row['NOME'] ?? '',
            'id_motorista': row['ID_MOTORISTA'] ?? 0,
            'id_veiculo': row['ID_VEICULO'] ?? 0,
            'data_coleta': row['DATA_COLETA'],
            'data_hora_inicio': row['DATA_HORA_INICIO'],
            'data_hora_fim': row['DATA_HORA_FIM'],
            'status': row['STATUS'] ?? 'PENDENTE',
          });
        }
        return list;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }

      final db = await DbConnection().db;
      final id = await _withCursor(db, (query) async {
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
        var v = 0;
        await for (var row in query.rows()) {
          v = row['ROT_ID'] ?? 0;
          break;
        }
        return v;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final rotId = int.tryParse(id) ?? 0;

      if (rotId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      // Tabela real do ERP (COLETAS_ROTA). O app envia status + horários;
      // COALESCE preserva o que não veio no payload.
      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE COLETAS_ROTA SET STATUS = COALESCE(?, STATUS), '
            'DATA_HORA_INICIO = COALESCE(?, DATA_HORA_INICIO), '
            'DATA_HORA_FIM = COALESCE(?, DATA_HORA_FIM) WHERE ID = ?',
        parameters: [
          data['status'],
          data['data_hora_inicio'],
          data['data_hora_fim'],
          rotId,
        ],
      ));

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
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE TB_ROTA SET ROT_STATUS = \'I\' WHERE ROT_ID = ?',
        parameters: [rotId],
      ));

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

      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(sql: sql, parameters: params);
        final list = <Map<String, dynamic>>[];
        await for (var row in query.rows()) {
          list.add({
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
        return list;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }

      final db = await DbConnection().db;
      final id = await _withCursor(db, (query) async {
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
        var v = 0;
        await for (var row in query.rows()) {
          v = row['PAR_ID'] ?? 0;
          break;
        }
        return v;
      });

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
      final data = await _readJsonBody(request);
      if (data == null) {
        return _errorResponse(400, 'Corpo inválido: esperado JSON de objeto');
      }
      final parId = int.tryParse(id) ?? 0;

      if (parId == 0) {
        return _errorResponse(400, 'ID inválido');
      }

      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
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
      ));

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

      // Exige multipart/form-data (shelf_multipart 2.0.1)
      final form = request.formData();
      if (form == null) {
        return _errorResponse(400, 'Requisição precisa ser multipart/form-data');
      }

      // Lê o primeiro campo que traz um arquivo (com filename).
      List<int>? fotoBytes;
      await for (final field in form.formData) {
        if (field.filename != null) {
          fotoBytes = await field.part.readBytes();
          break;
        }
      }

      if (fotoBytes == null || fotoBytes.isEmpty) {
        return _errorResponse(400, 'Nenhum arquivo de foto enviado');
      }

      // Valida tamanho e tipo (JPEG/PNG por magic number)
      if (fotoBytes.length > FileStorageService.maxFileSize) {
        return _errorResponse(413, 'Arquivo excede o limite de 10MB');
      }
      if (!FileStorageService.isValidImage(fotoBytes)) {
        return _errorResponse(415, 'Formato inválido (apenas JPEG ou PNG)');
      }

      // Salva o arquivo em disco (uploads/paradas/...)
      final fotoPath = await FileStorageService.saveFoto(parId, fotoBytes);
      if (fotoPath == null) {
        return _errorResponse(500, 'Falha ao salvar o arquivo');
      }

      // Persiste o caminho na coleta (tabela real do ERP: COLETAS_DETALHE).
      final db = await DbConnection().db;
      await _withCursor(db, (query) => query.openCursor(
        sql: 'UPDATE COLETAS_DETALHE SET FOTO_CAMINHO = ? WHERE ID = ?',
        parameters: [fotoPath, parId],
      ));

      _logger.info('ApiServer', 'Foto da coleta $parId salva em $fotoPath');
      return shelf.Response.ok(
          jsonEncode({'success': true, 'foto_path': fotoPath}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      _logger.error('ApiServer', 'Erro ao upload foto: $e');
      return _errorResponse(500, 'Erro ao upload de foto: $e');
    }
  }

  // ============ HELPERS ============

  /// Executa um bloco usando um cursor e garante o `close()` mesmo se a query
  /// falhar no meio (evita vazar cursores no erro). Retorna o valor do bloco.
  static Future<T> _withCursor<T>(
      dynamic db, Future<T> Function(dynamic query) body) async {
    final query = db.query();
    try {
      return await body(query);
    } finally {
      await query.close();
    }
  }

  /// Lê e valida o corpo JSON da requisição. Retorna o mapa ou null se o corpo
  /// estiver vazio/malformado/não for um objeto — o handler devolve 400.
  static Future<Map<String, dynamic>?> _readJsonBody(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      if (body.trim().isEmpty) return null;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

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
