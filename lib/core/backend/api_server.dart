import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';
import '../app_info.dart';
import '../logging/app_logger.dart';
import '../../features/core/config/config_service.dart';
import '../../features/core/database/db_connection.dart';
import '../../features/core/database/daos/mobile_sync_log_dao.dart';
import '../../features/core/sync/sync_activity_service.dart';
import 'jwt_service.dart';
import 'file_storage_service.dart';

/// Servidor HTTP integrado para sincronização mobile ↔ desktop.
///
/// Roda no isolate principal, junto da UI: o shelf é totalmente assíncrono,
/// e assim o servidor compartilha `ConfigService`/`DbConnection` com o resto
/// do app. Em isolate separado ele enxergava uma configuração zerada e só
/// `/ping` funcionava — todo endpoint que toca o banco respondia 500.
class ApiServer {
  static const int DEFAULT_PORT = 8080;
  static late AppLogger _logger;
  static HttpServer? _server;

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
        // Antes de /coleta/veiculos/<id>: senão "placa" cairia na rota do id.
        ..get('/coleta/veiculos/placa/<placa>', _veiculoPorPlacaHandler)
        ..post('/coleta/veiculos', _createVeiculo)
        ..put('/coleta/veiculos/<id>', _updateVeiculo)
        ..delete('/coleta/veiculos/<id>', _deleteVeiculo)
        ..get('/coleta/rotas', _listRotas)
        ..post('/coleta/rotas', _createRota)
        ..put('/coleta/rotas/<id>', _updateRota)
        ..delete('/coleta/rotas/<id>', _deleteRota)
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

      // Middleware (caching, logging, CORS, compression)
      // REMOVIDO: rate limiting - desabilitado para dev/testes
      //
      // _mobileLogMiddleware fica por último, ou seja, é o mais interno: assim
      // ele vê o JSON cru (antes do gzip) e consegue contar os registros.
      final handler = shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_cacheMiddleware)
          .addMiddleware(_compressionMiddleware)
          .addMiddleware(_corsMiddleware)
          .addMiddleware(_mobileLogMiddleware)
          .addHandler(router);

      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      _logger.info('ApiServer', 'Servidor iniciado em http://0.0.0.0:$port');

      // Sem isto, um erro de configuração do banco só aparece como 500 mudo no
      // mobile: /ping responde OK (não usa banco) e todo o resto falha.
      final config = ConfigService();
      _logger.info(
        'ApiServer',
        'Banco: ${config.host}:${config.porta} ${config.caminhoBase}',
      );
      // Descarta o histórico antigo do log do mobile a cada inicialização.
      try {
        await MobileSyncLogDao().aparar();
      } catch (e) {
        _logger.warning('ApiServer', 'Falha ao aparar log de sync: $e');
      }

      if (!await DbConnection().testarConexao()) {
        _logger.error(
          'ApiServer',
          'Sem conexão com o Firebird em ${config.host}:${config.porta} '
              '(${config.caminhoBase}). O mobile vai conectar mas não vai '
              'sincronizar — ajuste os dados em Configurações.',
        );
      }
    } catch (e) {
      _logger.error('ApiServer', 'Erro ao iniciar servidor: $e');
      rethrow;
    }
  }

  /// Middleware Cache para GET requests
  static shelf.Middleware _cacheMiddleware = (innerHandler) {
    return (request) async {
      // Só cacheia GET requests
      if (request.method != 'GET') {
        return await innerHandler(request);
      }

      // Dados de sincronização nunca saem do cache: com 5 minutos de TTL o
      // mobile recebia o que o desktop tinha antes da última alteração, e a
      // requisição sequer chegava ao handler (não aparecia no log de sync).
      if (request.url.path.startsWith('coleta/')) {
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

  /// Registra cada requisição do mobile em `tb_mobile_sync_log`, para a tela
  /// de Sincronização mostrar o que o celular baixou e enviou.
  ///
  /// Sem isto não havia rastro nenhum: a fila `tb_sync_queue` só guarda as
  /// escritas que o próprio desktop enfileira quando o Firebird está fora.
  static shelf.Middleware _mobileLogMiddleware = (innerHandler) {
    return (request) async {
      final inicio = DateTime.now();
      final rota = '/${request.url.path}';

      shelf.Response resposta;
      String? erro;
      int? registros;

      try {
        resposta = await innerHandler(request);
      } catch (e) {
        // Registra a falha e deixa o erro seguir para o shelf responder 500.
        await _gravarLog(
          inicio: inicio,
          request: request,
          rota: rota,
          statusHttp: 500,
          erro: '$e',
        );
        rethrow;
      }

      // Lê o corpo uma vez para contar os registros e devolve uma resposta
      // equivalente — um Stream de resposta só pode ser consumido uma vez.
      if (resposta.headers['content-type']?.contains('json') ?? false) {
        try {
          final corpo = await resposta.readAsString();
          registros = _contarRegistros(corpo);
          if (resposta.statusCode >= 400) {
            erro = _extrairErro(corpo);
          }
          resposta = resposta.change(body: corpo);
        } catch (_) {
          // Corpo ilegível não pode impedir a resposta de sair.
        }
      }

      await _gravarLog(
        inicio: inicio,
        request: request,
        rota: rota,
        statusHttp: resposta.statusCode,
        registros: registros,
        erro: erro,
      );

      // Avisa a interface ao vivo: alimenta o card de sincronização e faz as
      // telas se recarregarem quando o celular grava algo.
      SyncActivityService().registrar(
        SyncActivity(
          descricao: _descreverRota(request.method, rota),
          metodo: request.method,
          rota: rota,
          registros: registros,
          sucesso: resposta.statusCode >= 200 && resposta.statusCode < 300,
        ),
      );

      return resposta;
    };
  };

  static Future<void> _gravarLog({
    required DateTime inicio,
    required shelf.Request request,
    required String rota,
    required int statusHttp,
    int? registros,
    String? erro,
  }) async {
    try {
      final conexao =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      await MobileSyncLogDao().insert(
        MobileSyncLogItem(
          dataHora: inicio.toIso8601String(),
          metodo: request.method,
          rota: rota,
          descricao: _descreverRota(request.method, rota),
          statusHttp: statusHttp,
          registros: registros,
          duracaoMs: DateTime.now().difference(inicio).inMilliseconds,
          clienteIp: conexao?.remoteAddress.address,
          erro: erro,
        ),
      );
    } catch (e) {
      // Log é acessório: nunca pode derrubar a resposta ao mobile.
      _logger.warning('ApiServer', 'Falha ao gravar log de sync: $e');
    }
  }

  /// Quantos itens vieram em `data`, quando a resposta segue o contrato
  /// `{success, data: [...]}` das listagens.
  static int? _contarRegistros(String corpo) {
    try {
      final json = jsonDecode(corpo);
      if (json is Map && json['data'] is List) {
        return (json['data'] as List).length;
      }
      if (json is Map && json['aplicados'] is int) {
        return json['aplicados'] as int;
      }
    } catch (_) {
      // Resposta que não é JSON de objeto — sem contagem.
    }
    return null;
  }

  static String? _extrairErro(String corpo) {
    try {
      final json = jsonDecode(corpo);
      if (json is Map && json['error'] != null) return '${json['error']}';
    } catch (_) {
      // ignora
    }
    return null;
  }

  /// Nome legível da operação, para a tela não exibir só a URL.
  static String _descreverRota(String metodo, String rota) {
    if (rota == '/ping' || rota == '/health') return 'Teste de conexão';
    if (rota == '/auth/login') return 'Login do mobile';
    if (rota == '/auth/logout') return 'Logout do mobile';
    if (rota == '/coleta/sync') return 'Envio de coletas pendentes';
    if (rota.endsWith('/detalhes')) return 'Coletas da rota';
    if (rota.contains('/foto')) return 'Foto da coleta';
    if (rota.startsWith('/coleta/detalhes/')) return 'Atualização de coleta';

    const nomes = {
      'produtores': 'Produtores',
      'pessoas': 'Produtores',
      'motoristas': 'Motoristas',
      'veiculos': 'Veículos',
      'resfriadores': 'Resfriadores',
      'colaboradores': 'Colaboradores',
      'rotas': 'Rotas',
    };
    for (final entry in nomes.entries) {
      if (rota.startsWith('/coleta/${entry.key}')) {
        final acao = switch (metodo) {
          'POST' => 'Cadastro de ',
          'PUT' => 'Alteração de ',
          'DELETE' => 'Exclusão de ',
          _ => '',
        };
        return '$acao${entry.value}';
      }
    }
    return rota;
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

  /// Health check. Devolve a versão em execução — assim dá para saber qual
  /// retaguarda está atendendo sem abrir a interface da máquina.
  static shelf.Response _health(shelf.Request request) {
    return shelf.Response.ok(
      _encodeJson({
        'status': 'ok',
        'server': 'Coleta Retaguarda',
        'versao': appVersao,
      }),
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
            body: _encodeJson({'error': 'Login e senha obrigatórios'}),
            headers: {'Content-Type': 'application/json'});
      }

      final db = await DbConnection().db;
      var found = false;
      String nome = '';
      String perfil = 'OPERADOR';

      // Mesma tolerância do login da retaguarda: a TB_USUARIO vem do ERP e
      // cada instalação preencheu essas colunas de um jeito. Comparar no WHERE
      // com igualdade exata e exigir USU_STATUS = 'A' deixava de fora quem
      // tivesse o login em outra caixa, espaços à direita (a coluna é CHAR de
      // tamanho fixo) ou o status em branco, comum em cadastro antigo.
      String texto(dynamic v) => v == null ? '' : '$v'.trim();
      final loginProcurado = login.trim().toLowerCase();
      final senhaInformada = senha.trim();

      await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT USU_ID, USU_NOME, USU_LOGIN, USU_SENHA, '
              'USU_ADMINISTRADOR, USU_STATUS FROM TB_USUARIO',
        );
        await for (var row in query.rows()) {
          if (texto(row['USU_LOGIN']).toLowerCase() != loginProcurado) continue;
          if (texto(row['USU_SENHA']) != senhaInformada) continue;
          if (texto(row['USU_STATUS']).toUpperCase() == 'I') continue;

          found = true;
          nome = texto(row['USU_NOME']);
          // Vem de USU_ADMINISTRADOR ('S'/'N'). USU_PERFIL nesta base é
          // INTEGER — código do grupo de permissões do ERP —, então lê-lo
          // como rótulo devolvia "1" e ninguém era administrador no celular:
          // os cadastros ficavam bloqueados para todos.
          perfil = texto(row['USU_ADMINISTRADOR']).toUpperCase() == 'S'
              ? 'ADMINISTRADOR'
              : 'OPERADOR';
          break;
        }
      });

      if (!found) {
        _logger.warning('ApiServer', 'Falha de login: $login');
        return shelf.Response(401,
            body: _encodeJson({'error': 'Credenciais inválidas'}),
            headers: {'Content-Type': 'application/json'});
      }

      final token = JwtService.generateToken(1, nome, perfil);
      _logger.info('ApiServer', 'Login OK: $login ($perfil)');

      return shelf.Response.ok(
        _encodeJson({
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
          body: _encodeJson({'error': 'Erro interno'}),
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
        _encodeJson({'success': true, 'data': items}),
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
        _encodeJson({'success': true, 'data': items}),
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
        _encodeJson({'success': true, 'data': items}),
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
        _encodeJson({'success': true, 'data': items}),
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
              'VOLUME_COLETADO_LITROS, TEMPERATURA_LEITE_C, OBSERVACAO, '
              'MOTIVO_ADIAMENTO, FOTO_CAMINHO, ASSINATURA_BASE64, '
              'GPS_CAPTURA_LAT, GPS_CAPTURA_LON, HORARIO_CHEGADA, '
              'DATA_HORA_REGISTRO '
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
            'observacao': row['OBSERVACAO'] ?? '',
            'motivo_adiamento': row['MOTIVO_ADIAMENTO'] ?? '',
            'status': row['STATUS'] ?? 'PENDENTE',
            'foto_caminho': row['FOTO_CAMINHO'],
            'assinatura_base64': row['ASSINATURA_BASE64'],
            'gps_captura_lat': row['GPS_CAPTURA_LAT'],
            'gps_captura_lon': row['GPS_CAPTURA_LON'],
            'horario_chegada': row['HORARIO_CHEGADA'],
          });
        }
        return list;
      });
      return shelf.Response.ok(
        _encodeJson({'success': true, 'data': items}),
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
            'OBSERVACAO = COALESCE(?, OBSERVACAO), '
            'MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO), '
            'FOTO_CAMINHO = COALESCE(?, FOTO_CAMINHO), '
            'ASSINATURA_BASE64 = COALESCE(?, ASSINATURA_BASE64), '
            'GPS_CAPTURA_LAT = COALESCE(?, GPS_CAPTURA_LAT), '
            'GPS_CAPTURA_LON = COALESCE(?, GPS_CAPTURA_LON), '
            'HORARIO_CHEGADA = COALESCE(?, HORARIO_CHEGADA), '
            'DATA_HORA_REGISTRO = COALESCE(?, DATA_HORA_REGISTRO) '
            'WHERE ID = ?',
        parameters: [
          data['status'],
          _paraDouble(data['volume_coletado_litros']),
          _paraDouble(data['temperatura_leite_c']),
          data['observacao'],
          data['motivo_adiamento'],
          fotoServer,
          data['assinatura_base64'],
          _paraDouble(data['gps_captura_lat']),
          _paraDouble(data['gps_captura_lon']),
          _paraDataHora(data['horario_chegada']),
          _paraDataHora(data['data_hora_registro']),
          detId,
        ],
      ));
      return shelf.Response.ok(
        _encodeJson({'success': true}),
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
              _paraDataHora(rota['data_hora_inicio']),
              _paraDataHora(rota['data_hora_fim']),
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
                'OBSERVACAO = COALESCE(?, OBSERVACAO), '
                'MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO), '
                'FOTO_CAMINHO = COALESCE(?, FOTO_CAMINHO), '
                'ASSINATURA_BASE64 = COALESCE(?, ASSINATURA_BASE64), '
                'GPS_CAPTURA_LAT = COALESCE(?, GPS_CAPTURA_LAT), '
                'GPS_CAPTURA_LON = COALESCE(?, GPS_CAPTURA_LON), '
                'HORARIO_CHEGADA = COALESCE(?, HORARIO_CHEGADA), '
                'DATA_HORA_REGISTRO = COALESCE(?, DATA_HORA_REGISTRO) '
                'WHERE ID = ?',
            parameters: [
              det['status'],
              _paraDouble(det['volume_coletado_litros']),
              _paraDouble(det['temperatura_leite_c']),
              det['observacao'],
              det['motivo_adiamento'],
              fotoServer,
              det['assinatura_base64'],
              _paraDouble(det['gps_captura_lat']),
              _paraDouble(det['gps_captura_lon']),
              _paraDataHora(det['horario_chegada']),
              _paraDataHora(det['data_hora_registro']),
              detId,
            ],
          ));
          aplicados++;
        }
      }

      return shelf.Response.ok(
        _encodeJson({'success': true, 'aplicados': aplicados}),
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
      _encodeJson({'success': true}),
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
            _paraDouble(data['latitude']) ?? 0.0,
            _paraDouble(data['longitude']) ?? 0.0,
            _paraDouble(data['volume_medio']) ?? 0.0,
            data['hr_coleta'] ?? '',
            _paraDouble(data['km']) ?? 0.0,
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
          body: _encodeJson({'success': true, 'id': id}),
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
          _paraDouble(data['latitude']) ?? 0.0,
          _paraDouble(data['longitude']) ?? 0.0,
          _paraDouble(data['volume_medio']) ?? 0.0,
          data['hr_coleta'] ?? '',
          _paraDouble(data['km']) ?? 0.0,
          pesId,
        ],
      ));

      return shelf.Response.ok(
          _encodeJson({'success': true}),
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
          _encodeJson({'success': true}),
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
              'PES_BAIRRO, PES_CIDADE, PES_CEP, PES_CNH, PES_VALIDADE_CNH, '
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
            'cnh_validade': row['PES_VALIDADE_CNH'],
            'status': row['PES_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
          });
        }
        return list;
      });

      return shelf.Response.ok(
        _encodeJson({'success': true, 'data': items}),
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
              'PES_CIDADE, PES_CEP, PES_CNH, PES_VALIDADE_CNH, '
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
          body: _encodeJson({'success': true, 'id': id}),
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
            'PES_CEP = ?, PES_CNH = ?, PES_VALIDADE_CNH = ? '
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
          _encodeJson({'success': true}),
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
          _encodeJson({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar motorista: $e');
    }
  }

  // ============ VEICULOS ============

  /// Rótulo do veículo para o mobile.
  ///
  /// Vem de VEI_DESCRICAO, que é o nome dado ao carro no cadastro. Cadastros
  /// antigos do ERP têm essa coluna vazia, e para esses ainda vale marca +
  /// modelo — melhor do que mostrar uma linha em branco na escolha do veículo.
  static String _rotuloVeiculo(dynamic row) {
    final descricao = '${row['VEI_DESCRICAO'] ?? ''}'.trim();
    if (descricao.isNotEmpty) return descricao;
    return [row['VEI_MARCA'], row['VEI_MODELO']]
        .where((e) => e != null && '$e'.trim().isNotEmpty)
        .join(' ')
        .trim();
  }

  /// Só letras e números, em maiúsculas — a base guarda placa com e sem hífen.
  static String _normalizarPlaca(String placa) =>
      placa.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Id do veículo com esta placa, ou nulo se não houver.
  static Future<int?> _veiculoPorPlaca(dynamic db, String placa) async {
    final alvo = _normalizarPlaca(placa);
    if (alvo.isEmpty) return null;
    final rows = await db.selectAll(
      sql: 'SELECT VEI_ID, VEI_PLACA FROM TB_VEICULO',
    );
    for (final row in rows) {
      if (_normalizarPlaca('${row['VEI_PLACA'] ?? ''}') == alvo) {
        return row['VEI_ID'] as int?;
      }
    }
    return null;
  }

  /// TB_VEICULO não tem generator nesta base; o id sai de MAX+1.
  static Future<int> _proximoIdVeiculo(dynamic db) async {
    final row = await db.selectOne(
      sql: 'SELECT COALESCE(MAX(VEI_ID),0)+1 AS NID FROM TB_VEICULO',
    );
    return (row?['NID'] as int?) ?? 1;
  }

  /// Grava os campos de um veículo já existente. Usado tanto pelo PUT quanto
  /// pelo POST que reencontrou a placa.
  static Future<void> _gravarVeiculo(
    dynamic db,
    int veiId,
    Map<String, dynamic> data,
    String placa,
  ) async {
    await _withCursor(db, (query) => query.openCursor(
      sql: 'UPDATE TB_VEICULO SET VEI_PLACA = ?, VEI_DESCRICAO = ?, '
          'VEI_MARCA = ?, VEI_MODELO = ?, VEI_COR = ?, VEI_ANO_FAB = ?, '
          'VEI_TIPO = ?, VEI_RENAVAM = ?, VEI_CHASSI = ? WHERE VEI_ID = ?',
      parameters: [
        placa,
        '${data['descricao'] ?? ''}'.trim(),
        data['marca'] ?? '',
        data['modelo'] ?? '',
        data['cor'] ?? '',
        int.tryParse('${data['ano'] ?? ''}') ?? 0,
        data['tipo'] ?? 'C',
        data['renavam'] ?? '',
        data['chassi'],
        veiId,
      ],
    ));
  }

  /// `GET /coleta/veiculos/placa/<placa>` — consulta por placa para o mobile.
  ///
  /// Devolve 404 quando a placa não está cadastrada: é assim que o celular
  /// sabe que pode seguir para um cadastro novo.
  static Future<shelf.Response> _veiculoPorPlacaHandler(
      shelf.Request request, String placa) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final alvo = _normalizarPlaca(Uri.decodeComponent(placa));
      if (alvo.isEmpty) return _errorResponse(400, 'Placa inválida');

      final db = await DbConnection().db;
      final rows = await db.selectAll(
        sql: 'SELECT VEI_ID, VEI_PLACA, VEI_DESCRICAO, VEI_MARCA, VEI_MODELO, '
            'VEI_COR, VEI_ANO_FAB, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, '
            'VEI_STATUS FROM TB_VEICULO',
      );

      for (final row in rows) {
        if (_normalizarPlaca('${row['VEI_PLACA'] ?? ''}') != alvo) continue;
        return shelf.Response.ok(
          _encodeJson({
            'success': true,
            'data': {
              'id': row['VEI_ID'],
              'placa': row['VEI_PLACA'],
              'descricao': _rotuloVeiculo(row),
              'marca': row['VEI_MARCA'] ?? '',
              'modelo': row['VEI_MODELO'] ?? '',
              'cor': row['VEI_COR'] ?? '',
              'ano': row['VEI_ANO_FAB'] ?? '',
              'tipo': row['VEI_TIPO'] ?? 'C',
              'renavam': row['VEI_RENAVAM'] ?? '',
              'chassi': row['VEI_CHASSI'],
              'status': row['VEI_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
            },
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return _errorResponse(404, 'Placa não cadastrada');
    } catch (e) {
      return _errorResponse(500, 'Erro ao consultar placa: $e');
    }
  }

  static Future<shelf.Response> _listVeiculos(shelf.Request request) async {
    final tokenData = _validateBearerToken(request);
    if (tokenData == null) {
      return _errorResponse(401, 'Token inválido ou expirado');
    }

    try {
      final db = await DbConnection().db;
      final items = await _withCursor(db, (query) async {
        await query.openCursor(
          sql: 'SELECT VEI_ID, VEI_PLACA, VEI_DESCRICAO, VEI_MARCA, '
              'VEI_MODELO, VEI_COR, VEI_ANO_FAB, VEI_TIPO, VEI_RENAVAM, '
              'VEI_CHASSI, VEI_STATUS '
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
            'descricao': _rotuloVeiculo(row),
            'cor': row['VEI_COR'] ?? '',
            'ano': row['VEI_ANO_FAB'] ?? '',
            'tipo': row['VEI_TIPO'] ?? 'C',
            'renavam': row['VEI_RENAVAM'] ?? '',
            'chassi': row['VEI_CHASSI'],
            'status': row['VEI_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
          });
        }
        return list;
      });

      return shelf.Response.ok(
        _encodeJson({'success': true, 'data': items}),
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

      final placa = '${data['placa'] ?? ''}'.trim().toUpperCase();
      if (placa.isEmpty) {
        return _errorResponse(400, 'Informe a placa do veículo');
      }

      final db = await DbConnection().db;

      // Placa repetida vira alteração do que já existe. Sem isto, cada vez que
      // alguém cadastrasse o mesmo carro no celular nasceria outro registro, e
      // a lista de veículos da rota encheria de duplicados.
      final existente = await _veiculoPorPlaca(db, placa);
      if (existente != null) {
        await _gravarVeiculo(db, existente, data, placa);
        return shelf.Response.ok(
            _encodeJson({
              'success': true,
              'id': existente,
              'atualizado': true,
              'mensagem': 'Placa já cadastrada: o veículo foi atualizado.',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      // TB_VEICULO não tem generator: o id sai de MAX+1, igual ao que a
      // retaguarda faz nos cadastros pela tela.
      final novoId = await _proximoIdVeiculo(db);
      await _withCursor(db, (query) => query.openCursor(
        sql: 'INSERT INTO TB_VEICULO (VEI_ID, VEI_EMPRESA, VEI_PLACA, '
            'VEI_DESCRICAO, VEI_MARCA, VEI_MODELO, VEI_COR, VEI_ANO_FAB, '
            'VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, VEI_STATUS) '
            'VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, \'A\')',
        parameters: [
          novoId,
          placa,
          '${data['descricao'] ?? ''}'.trim(),
          data['marca'] ?? '',
          data['modelo'] ?? '',
          data['cor'] ?? '',
          int.tryParse('${data['ano'] ?? ''}') ?? 0,
          data['tipo'] ?? 'C',
          data['renavam'] ?? '',
          data['chassi'],
        ],
      ));

      return shelf.Response(201,
          body: _encodeJson({'success': true, 'id': novoId}),
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
      await _gravarVeiculo(
        db,
        veiId,
        data,
        '${data['placa'] ?? ''}'.trim().toUpperCase(),
      );

      return shelf.Response.ok(
          _encodeJson({'success': true}),
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
          _encodeJson({'success': true}),
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
        _encodeJson({'success': true, 'data': items}),
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
            _paraDataHora(data['data_prevista']),
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
          body: _encodeJson({'success': true, 'id': id}),
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
          _paraDataHora(data['data_hora_inicio']),
          _paraDataHora(data['data_hora_fim']),
          rotId,
        ],
      ));

      return shelf.Response.ok(
          _encodeJson({'success': true}),
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
          _encodeJson({'success': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return _errorResponse(500, 'Erro ao deletar rota: $e');
    }
  }

  /// POST `/coleta/detalhes/<id>/foto` — anexa a foto da coleta.
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
          _encodeJson({'success': true, 'foto_path': fotoPath}),
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
        body: _encodeJson({'error': message, 'success': false}),
        headers: {'Content-Type': 'application/json'});
  }

  /// Converte para [DateTime] o que vem do JSON como texto ISO-8601.
  ///
  /// O `fbdb` recebe o parâmetro pelo tipo da coluna: mandar String numa coluna
  /// TIMESTAMP estoura `type 'String' is not a subtype of type 'DateTime'` e
  /// derruba o UPDATE inteiro. Era o que impedia volume, temperatura, status e
  /// observação de chegarem do mobile: a coleta ia junto com a data e a
  /// gravação toda falhava com 500, ficando pendente e retentando para sempre.
  static DateTime? _paraDataHora(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is String) {
      if (valor.trim().isEmpty) return null;
      return DateTime.tryParse(valor);
    }
    return null;
  }

  /// Converte para [double] o que o JSON entregou como [int].
  ///
  /// Mesmo problema do [_paraDataHora]: o `fbdb` exige o tipo exato da coluna.
  /// Um volume redondo (`500`) chega do `jsonDecode` como int e a coluna é
  /// decimal, estourando `type 'int' is not a subtype of type 'double'` — a
  /// gravação inteira falhava justamente nos valores mais comuns.
  static double? _paraDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) {
      if (valor.trim().isEmpty) return null;
      return double.tryParse(valor.replaceAll(',', '.'));
    }
    return null;
  }

  /// Serializa a resposta tratando os tipos que o `jsonEncode` não conhece.
  ///
  /// Colunas DATE/TIMESTAMP do Firebird chegam como [DateTime]; sem esta
  /// conversão o handler inteiro morre com 500 na hora de montar o JSON —
  /// era o que derrubava `/coleta/rotas`, cuja query roda sem erro no banco.
  static String _encodeJson(Object? data) => jsonEncode(
        data,
        toEncodable: (value) =>
            value is DateTime ? value.toIso8601String() : '$value',
      );

  static Future<void> stop() async {
    await _server?.close();
    _logger.info('ApiServer', 'Servidor parado');
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
