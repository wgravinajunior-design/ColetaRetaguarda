import 'package:fbdb/fbdb.dart';
import 'db_connection.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../rotas/models/rota_model.dart';
import '../../coleta/models/parada_model.dart';
import '../../motoristas/models/motorista_model.dart';
import '../../veiculos/models/veiculo_model.dart';
import '../../financeiro/models/movimento_model.dart';
import '../../resfriadores/models/resfriador_model.dart';

/// Referência simples (id + rótulo) para dropdowns.
class OpcaoRef {
  final int id;
  final String label;
  const OpcaoRef({required this.id, required this.label});
}

/// Conta financeira (TB_CONTA) — caixa ou banco.
class ContaRef {
  final int id;
  final String descricao;
  final String tipo; // 'C' = Caixa, 'B' = Banco
  const ContaRef({
    required this.id,
    required this.descricao,
    required this.tipo,
  });
  bool get isBanco => tipo.toUpperCase() == 'B';
}

/// Saldo acumulado de uma conta (entradas − saídas).
class SaldoConta {
  final int id;
  final String descricao;
  final String tipo; // 'C' = Caixa, 'B' = Banco
  final double saldo;
  const SaldoConta({
    required this.id,
    required this.descricao,
    required this.tipo,
    required this.saldo,
  });
  bool get isBanco => tipo.toUpperCase() == 'B';
}

/// Acesso direto à base Firebird (DADOS.FDB) configurada nas Configurações.
/// Lê/grava nas tabelas reais do ERP/Coleta:
///   - Produtores  → TB_PESSOA (PES_FORNECEDOR='S')
///   - Motoristas  → TB_PESSOA (PES_TRANSPORTADOR='S')
///   - Rotas       → COLETAS_ROTA
///   - Coletas     → COLETAS_DETALHE (JOIN TB_PESSOA)
class FirebirdService {
  static final FirebirdService _instance = FirebirdService._internal();
  factory FirebirdService() => _instance;
  FirebirdService._internal();

  Future<FbDb> get _db => DbConnection().db;

  // ───────────── Helpers de conversão ─────────────
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _toStr(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toIso8601String();
    return v.toString();
  }

  // ───────────── Mapeamento de status da coleta ─────────────
  // App: P=Pendente, E=Em Andamento, C=Sucesso, R=Recusado
  // Adiada e recusada eram o mesmo código 'R', então uma coleta apenas adiada
  // aparecia como recusada — situações diferentes na operação: adiada volta a
  // ser tentada, recusada não.
  static String statusColetaToDb(String s) => switch (s) {
    'E' => 'EM_ANDAMENTO',
    'C' => 'CONFIRMADO',
    'R' => 'RECUSADO',
    'A' => 'ADIADO',
    'X' => 'CANCELADO',
    _ => 'PENDENTE',
  };

  static String statusColetaFromDb(String? s) =>
      switch ((s ?? '').toUpperCase()) {
        'EM_ANDAMENTO' => 'E',
        'CONFIRMADO' => 'C',
        'RECUSADO' => 'R',
        'ADIADO' => 'A',
        'CANCELADO' => 'X',
        _ => 'P',
      };

  static String _montarEndereco(Map<String, dynamic> r) {
    final partes = <String>[];
    void add(String key, [String? prefixo]) {
      final v = r[key]?.toString().trim();
      if (v != null && v.isNotEmpty)
        partes.add(prefixo != null ? '$prefixo $v' : v);
    }

    add('PES_ENDERECO');
    add('PES_NUMERO', 'nº');
    add('PES_COMPLEMENTO');
    add('PES_BAIRRO');
    add('PES_CEP', 'CEP');
    return partes.join(', ');
  }

  // ═════════════ PRODUTORES ═════════════
  /// Lista produtores (TB_PESSOA, PES_FORNECEDOR='S').
  /// [status]: 'A' = ativos (padrão), 'I' = inativos, null = todos.
  Future<List<PessoaModel>> getProdutores({String? status = 'A'}) async {
    final db = await _db;
    final filtroStatus = (status != null && status.isNotEmpty)
        ? 'AND P.PES_STATUS = ?'
        : '';
    final rows = await db.selectAll(
      sql:
          '''
        SELECT P.PES_ID, P.PES_RSOCIAL_NOME, P.PES_CNPJ_CPF, P.PES_ENDERECO, P.PES_NUMERO,
               P.PES_COMPLEMENTO, P.PES_BAIRRO, P.PES_CEP, P.PES_STATUS,
               P.PES_TELEFONE, P.PES_CELULAR, P.PES_EMAIL,
               P.PES_LATITUDE, P.PES_LONGITUDE, P.PES_HR_COLETA, P.PES_KM, P.PES_VOLUME_MEDIO,
               P.PES_ID_RESFRIADOR, R.RES_NUMERO_ID, R.RES_MARCA_MODELO
        FROM TB_PESSOA P
        LEFT JOIN TB_RESFRIADOR R ON R.RES_ID = P.PES_ID_RESFRIADOR
        WHERE P.PES_FORNECEDOR = 'S' $filtroStatus
        ORDER BY P.PES_RSOCIAL_NOME
      ''',
      parameters: (status != null && status.isNotEmpty) ? [status] : const [],
    );
    return rows.map(_pessoaFromRow).toList();
  }

  /// Lista de resfriadores ativos (TB_RESFRIADOR) para vínculo com produtor.
  Future<List<OpcaoRef>> getResfriadoresRef() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT RES_ID, RES_NUMERO_ID, RES_MARCA_MODELO
        FROM TB_RESFRIADOR
        WHERE (RES_STATUS IS NULL OR RES_STATUS <> 'INATIVO')
        ORDER BY RES_NUMERO_ID
      ''',
    );
    return rows.map((r) {
      final num = _toStr(r['RES_NUMERO_ID']) ?? '';
      final mod = _toStr(r['RES_MARCA_MODELO']) ?? '';
      final label = [num, mod].where((e) => e.isNotEmpty).join(' - ');
      return OpcaoRef(
        id: _toInt(r['RES_ID']) ?? 0,
        label: label.isEmpty ? 'Resfriador ${r['RES_ID']}' : label,
      );
    }).toList();
  }

  /// Motoristas cadastrados no ERP (PES_TRANSPORTADOR='S'), apenas ativos.
  Future<List<OpcaoRef>> getMotoristasRef() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT PES_ID, PES_RSOCIAL_NOME
        FROM TB_PESSOA
        WHERE PES_TRANSPORTADOR = 'S' AND (PES_STATUS IS NULL OR PES_STATUS <> 'I')
        ORDER BY PES_RSOCIAL_NOME
      ''',
    );
    return rows
        .map(
          (r) => OpcaoRef(
            id: _toInt(r['PES_ID']) ?? 0,
            label: _toStr(r['PES_RSOCIAL_NOME']) ?? '',
          ),
        )
        .toList();
  }

  /// Veículos cadastrados no ERP, apenas ativos.
  Future<List<OpcaoRef>> getVeiculosRef() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT VEI_ID, VEI_PLACA, VEI_MODELO
        FROM TB_VEICULO
        WHERE (VEI_STATUS IS NULL OR VEI_STATUS <> 'I')
        ORDER BY VEI_PLACA
      ''',
    );
    return rows.map((r) {
      final placa = _toStr(r['VEI_PLACA']) ?? '';
      final modelo = _toStr(r['VEI_MODELO']) ?? '';
      final label = [placa, modelo].where((e) => e.isNotEmpty).join(' - ');
      return OpcaoRef(
        id: _toInt(r['VEI_ID']) ?? 0,
        label: label.isEmpty ? 'Veículo ${r['VEI_ID']}' : label,
      );
    }).toList();
  }

  PessoaModel _pessoaFromRow(Map<String, dynamic> r) {
    final resNumero = _toStr(r['RES_NUMERO_ID']);
    final resModelo = _toStr(r['RES_MARCA_MODELO']);
    final resNome = resNumero == null
        ? null
        : [
            resNumero,
            if (resModelo != null && resModelo.isNotEmpty) resModelo,
          ].join(' - ');
    return PessoaModel(
      id: _toInt(r['PES_ID']),
      tipoPessoa: 'P',
      rSocialNome: _toStr(r['PES_RSOCIAL_NOME']) ?? '',
      cnpjCpf: _toStr(r['PES_CNPJ_CPF']) ?? '',
      endereco: _toStr(r['PES_ENDERECO']) ?? '',
      numero: _toStr(r['PES_NUMERO']) ?? '',
      complemento: _toStr(r['PES_COMPLEMENTO']) ?? '',
      bairro: _toStr(r['PES_BAIRRO']) ?? '',
      cep: _toStr(r['PES_CEP']) ?? '',
      telefone: _toStr(r['PES_TELEFONE']) ?? '',
      celular: _toStr(r['PES_CELULAR']) ?? '',
      email: _toStr(r['PES_EMAIL']) ?? '',
      status: _toStr(r['PES_STATUS']) ?? 'A',
      cliente: 'N',
      latitude: _toDouble(r['PES_LATITUDE']),
      longitude: _toDouble(r['PES_LONGITUDE']),
      horarioColeta: _toStr(r['PES_HR_COLETA']),
      km: _toDouble(r['PES_KM']),
      volumeMedio: _toDouble(r['PES_VOLUME_MEDIO']),
      resfriadorId: _toInt(r['PES_ID_RESFRIADOR']),
      resfriadorNome: resNome,
    );
  }

  // ═════════════ ROTAS ═════════════
  Future<List<RotaModel>> getRotas({
    String? status,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    final db = await _db;
    final where = <String>[];
    final params = <dynamic>[];
    if (status != null && status.isNotEmpty) {
      where.add('R.STATUS = ?');
      params.add(status);
    }
    if (inicio != null) {
      where.add('R.DATA_COLETA >= ?');
      params.add(DateTime(inicio.year, inicio.month, inicio.day));
    }
    if (fim != null) {
      where.add('R.DATA_COLETA <= ?');
      params.add(DateTime(fim.year, fim.month, fim.day, 23, 59, 59));
    }
    final filtro = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final rows = await db.selectAll(
      sql:
          '''
        SELECT R.ID, R.NOME, R.ID_MOTORISTA, R.ID_VEICULO, R.DATA_COLETA,
               R.DATA_HORA_INICIO, R.DATA_HORA_FIM, R.STATUS,
               (SELECT COUNT(*) FROM COLETAS_DETALHE D WHERE D.ID_COLETA_ROTA = R.ID) AS QTD_PARADAS,
               (SELECT COUNT(*) FROM COLETAS_DETALHE D WHERE D.ID_COLETA_ROTA = R.ID
                  AND D.STATUS = 'CONFIRMADO') AS QTD_FEITAS
        FROM COLETAS_ROTA R
        $filtro
        ORDER BY R.DATA_COLETA DESC
      ''',
      parameters: params,
    );
    return rows
        .map(
          (r) => RotaModel(
            id: _toInt(r['ID']),
            descricao: _toStr(r['NOME']) ?? '',
            motoristaId: _toInt(r['ID_MOTORISTA']),
            veiculoId: _toInt(r['ID_VEICULO']),
            status: _toStr(r['STATUS']) ?? 'PENDENTE',
            dataPrevista: _toStr(r['DATA_COLETA']),
            dataInicio: _toStr(r['DATA_HORA_INICIO']),
            dataFim: _toStr(r['DATA_HORA_FIM']),
            paradas: _toInt(r['QTD_PARADAS']) ?? 0,
            paradasFeitas: _toInt(r['QTD_FEITAS']) ?? 0,
          ),
        )
        .toList();
  }

  // ═════════════ COLETAS (paradas) ═════════════
  static const String _selectColeta = '''
    SELECT D.ID, D.ID_COLETA_ROTA, D.ID_PRODUTOR, D.ORDEM_VISITA, D.STATUS,
           D.VOLUME_COLETADO_LITROS, D.TEMPERATURA_LEITE_C, D.MOTIVO_ADIAMENTO,
           D.FOTO_CAMINHO, D.ASSINATURA_BASE64, D.DATA_HORA_REGISTRO,
           D.GPS_CAPTURA_LAT, D.GPS_CAPTURA_LON, D.HORARIO_CHEGADA,
           P.PES_RSOCIAL_NOME, P.PES_CNPJ_CPF, P.PES_ENDERECO, P.PES_NUMERO,
           P.PES_COMPLEMENTO, P.PES_BAIRRO, P.PES_CEP, P.PES_LATITUDE, P.PES_LONGITUDE
    FROM COLETAS_DETALHE D
    JOIN TB_PESSOA P ON P.PES_ID = D.ID_PRODUTOR
    LEFT JOIN COLETAS_ROTA R ON R.ID = D.ID_COLETA_ROTA
  ''';

  ParadaModel _paradaFromRow(Map<String, dynamic> r) {
    return ParadaModel(
      id: _toInt(r['ID']),
      rotaId: _toInt(r['ID_COLETA_ROTA']),
      pessoaId: _toInt(r['ID_PRODUTOR']),
      pessoaNome: _toStr(r['PES_RSOCIAL_NOME']) ?? '',
      cnpjCpf: _toStr(r['PES_CNPJ_CPF']) ?? '',
      endereco: _montarEndereco(r),
      latitude: _toDouble(r['PES_LATITUDE']) ?? 0.0,
      longitude: _toDouble(r['PES_LONGITUDE']) ?? 0.0,
      status: statusColetaFromDb(_toStr(r['STATUS'])),
      temperatura: _toDouble(r['TEMPERATURA_LEITE_C']),
      volume: _toDouble(r['VOLUME_COLETADO_LITROS']),
      justificativa: _toStr(r['MOTIVO_ADIAMENTO']),
      fotoPath: _toStr(r['FOTO_CAMINHO']),
      assinaturaBase64: _toStr(r['ASSINATURA_BASE64']),
      gpsCapturaLatitude: _toDouble(r['GPS_CAPTURA_LAT']),
      gpsCapturaltitude: _toDouble(r['GPS_CAPTURA_LON']),
      horarioChegada:
          _toStr(r['HORARIO_CHEGADA']) ?? _toStr(r['DATA_HORA_REGISTRO']),
    );
  }

  /// Grava o GPS capturado no momento da coleta + horário de chegada.
  Future<bool> registrarGpsColeta(
    int paradaId,
    double latitude,
    double longitude, {
    String? horarioChegada,
  }) async {
    final db = await _db;
    final chegada = horarioChegada != null
        ? DateTime.tryParse(horarioChegada)
        : null;
    await db.execute(
      sql: '''
        UPDATE COLETAS_DETALHE SET
          GPS_CAPTURA_LAT = ?,
          GPS_CAPTURA_LON = ?,
          HORARIO_CHEGADA = COALESCE(?, HORARIO_CHEGADA, CURRENT_TIMESTAMP)
        WHERE ID = ?
      ''',
      parameters: [latitude, longitude, chegada, paradaId],
    );
    return true;
  }

  Future<List<ParadaModel>> getParadasByRota(int rotaId) async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '$_selectColeta WHERE D.ID_COLETA_ROTA = ? ORDER BY D.ORDEM_VISITA',
      parameters: [rotaId],
    );
    return rows.map(_paradaFromRow).toList();
  }

  /// Coletas, opcionalmente recortadas por situação e pela data da rota.
  Future<List<ParadaModel>> getTodasColetas({
    String? status,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    final db = await _db;
    final where = <String>[];
    final params = <dynamic>[];

    if (status != null) {
      where.add('D.STATUS = ?');
      params.add(statusColetaToDb(status));
    }
    // A data que interessa é a do dia da rota, não a de registro: uma coleta
    // ainda pendente não tem registro, e mesmo assim pertence ao dia.
    if (inicio != null) {
      where.add('R.DATA_COLETA >= ?');
      params.add(DateTime(inicio.year, inicio.month, inicio.day));
    }
    if (fim != null) {
      where.add('R.DATA_COLETA <= ?');
      params.add(DateTime(fim.year, fim.month, fim.day, 23, 59, 59));
    }

    final filtro = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.selectAll(
      sql: '$_selectColeta $filtro ORDER BY D.ID DESC',
      parameters: params,
    );
    return rows.map(_paradaFromRow).toList();
  }

  Future<ParadaModel?> getParadaById(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: '$_selectColeta WHERE D.ID = ?',
      parameters: [id],
    );
    return row == null ? null : _paradaFromRow(row);
  }

  Future<int> _proximoId(String tabela) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COALESCE(MAX(ID),0)+1 AS NID FROM $tabela',
    );
    return _toInt(row?['NID']) ?? 1;
  }

  /// Cria uma parada (COLETAS_DETALHE) vinculada a uma rota e produtor.
  Future<ParadaModel?> criarParada(ParadaModel parada) async {
    final db = await _db;
    final novoId = await _proximoId('COLETAS_DETALHE');

    // Próxima ordem de visita dentro da rota
    final ordemRow = await db.selectOne(
      sql:
          'SELECT COALESCE(MAX(ORDEM_VISITA),0)+1 AS NORD FROM COLETAS_DETALHE WHERE ID_COLETA_ROTA = ?',
      parameters: [parada.rotaId],
    );
    final ordem = _toInt(ordemRow?['NORD']) ?? 1;

    await db.execute(
      sql: '''
        INSERT INTO COLETAS_DETALHE
          (ID, ID_COLETA_ROTA, ID_PRODUTOR, ORDEM_VISITA, STATUS)
        VALUES (?, ?, ?, ?, ?)
      ''',
      parameters: [
        novoId,
        parada.rotaId,
        parada.pessoaId,
        ordem,
        statusColetaToDb(parada.status),
      ],
    );

    return await getParadaById(novoId);
  }

  /// Atualiza o status/dados de uma coleta (confirmar, recusar, etc.).
  /// Rotas que ainda aceitam coletas: pendentes ou em andamento.
  ///
  /// É o destino possível ao mover uma coleta adiada — rota concluída não
  /// recebe parada nova.
  Future<List<RotaModel>> getRotasEmAberto() => getRotas().then(
    (rotas) => rotas
        .where((r) => r.status == 'PENDENTE' || r.status == 'EM_ANDAMENTO')
        .toList(),
  );

  /// Move uma coleta para outra rota, no fim da ordem de visita.
  ///
  /// Usado quando o produtor foi adiado e a coleta passa para outro dia ou
  /// outro motorista, em vez de virar um registro perdido.
  Future<bool> moverColetaParaRota({
    required int paradaId,
    required int novaRotaId,
  }) async {
    final db = await _db;
    final row = await db.selectOne(
      sql:
          'SELECT COALESCE(MAX(ORDEM_VISITA), 0) + 1 AS PROX '
          'FROM COLETAS_DETALHE WHERE ID_COLETA_ROTA = ?',
      parameters: [novaRotaId],
    );
    final ordem = _toInt(row?['PROX']) ?? 1;

    await db.execute(
      sql:
          'UPDATE COLETAS_DETALHE SET ID_COLETA_ROTA = ?, ORDEM_VISITA = ? '
          'WHERE ID = ?',
      parameters: [novaRotaId, ordem, paradaId],
    );
    return true;
  }

  /// Troca só a situação, sem tocar nas medições.
  ///
  /// [atualizarStatusColeta] grava DATA_HORA_REGISTRO como agora, o que
  /// reescreveria o momento em que a coleta foi de fato registrada.
  Future<bool> alterarSituacaoColeta({
    required int paradaId,
    required String novoStatus,
    String? justificativa,
  }) async {
    final db = await _db;
    await db.execute(
      sql:
          'UPDATE COLETAS_DETALHE SET STATUS = ?, '
          'MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO) WHERE ID = ?',
      parameters: [statusColetaToDb(novoStatus), justificativa, paradaId],
    );
    return true;
  }

  Future<bool> atualizarStatusColeta({
    required int paradaId,
    required String novoStatus,
    double? temperatura,
    double? volume,
    String? justificativa,
    String? assinaturaBase64,
    String? fotoPath,
  }) async {
    final db = await _db;
    await db.execute(
      sql: '''
        UPDATE COLETAS_DETALHE SET
          STATUS = ?,
          VOLUME_COLETADO_LITROS = COALESCE(?, VOLUME_COLETADO_LITROS),
          TEMPERATURA_LEITE_C = COALESCE(?, TEMPERATURA_LEITE_C),
          MOTIVO_ADIAMENTO = COALESCE(?, MOTIVO_ADIAMENTO),
          FOTO_CAMINHO = COALESCE(?, FOTO_CAMINHO),
          ASSINATURA_BASE64 = COALESCE(?, ASSINATURA_BASE64),
          DATA_HORA_REGISTRO = CURRENT_TIMESTAMP
        WHERE ID = ?
      ''',
      parameters: [
        statusColetaToDb(novoStatus),
        volume,
        temperatura,
        justificativa,
        fotoPath,
        assinaturaBase64,
        paradaId,
      ],
    );
    return true;
  }

  // ═════════════ CRUD ROTAS (COLETAS_ROTA) ═════════════
  Future<RotaModel?> criarRota(RotaModel r) async {
    if (r.motoristaId == null || r.veiculoId == null) {
      throw Exception(
        'Motorista e veículo são obrigatórios para criar a rota.',
      );
    }
    final db = await _db;
    final novoId = await _proximoId('COLETAS_ROTA');
    final dataColeta = r.dataPrevista != null
        ? DateTime.tryParse(r.dataPrevista!) ?? DateTime.now()
        : DateTime.now();

    await db.execute(
      sql: '''
        INSERT INTO COLETAS_ROTA (ID, NOME, ID_MOTORISTA, ID_VEICULO, DATA_COLETA, STATUS)
        VALUES (?, ?, ?, ?, ?, ?)
      ''',
      parameters: [
        novoId,
        r.descricao,
        r.motoristaId,
        r.veiculoId,
        dataColeta,
        r.status.isEmpty ? 'PENDENTE' : r.status,
      ],
    );
    r.id = novoId;
    return r;
  }

  Future<bool> atualizarRota(RotaModel r) async {
    if (r.id == null) return false;
    final db = await _db;
    final dataColeta = r.dataPrevista != null
        ? DateTime.tryParse(r.dataPrevista!)
        : null;
    await db.execute(
      sql: '''
        UPDATE COLETAS_ROTA SET
          NOME = ?,
          ID_MOTORISTA = COALESCE(?, ID_MOTORISTA),
          ID_VEICULO = COALESCE(?, ID_VEICULO),
          DATA_COLETA = COALESCE(?, DATA_COLETA),
          STATUS = ?
        WHERE ID = ?
      ''',
      parameters: [
        r.descricao,
        r.motoristaId,
        r.veiculoId,
        dataColeta,
        r.status,
        r.id,
      ],
    );
    return true;
  }

  /// Verifica se a rota já possui coletas/paradas (movimentação).
  Future<bool> rotaTemMovimentacao(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql:
          'SELECT COUNT(*) AS QTD FROM COLETAS_DETALHE WHERE ID_COLETA_ROTA = ?',
      parameters: [id],
    );
    return (_toInt(row?['QTD']) ?? 0) > 0;
  }

  Future<bool> excluirRota(int id) async {
    if (await rotaTemMovimentacao(id)) {
      throw Exception(
        'A rota possui coletas registradas e não pode ser excluída.',
      );
    }
    final db = await _db;
    await db.execute(
      sql: 'DELETE FROM COLETAS_ROTA WHERE ID = ?',
      parameters: [id],
    );
    return true;
  }

  /// Altera o status da rota (PENDENTE, LIBERADA, EM_ANDAMENTO, CONCLUIDA).
  Future<bool> atualizarStatusRota(int rotaId, String status) async {
    final db = await _db;
    await db.execute(
      sql: 'UPDATE COLETAS_ROTA SET STATUS = ? WHERE ID = ?',
      parameters: [status, rotaId],
    );
    return true;
  }

  /// Quantas coletas da rota ainda estão em aberto (pendente ou em andamento).
  ///
  /// Serve para avisar antes de encerrar: fechar com coleta pendente deixa o
  /// produtor sem registro de atendimento naquele dia.
  Future<int> coletasEmAbertoNaRota(int rotaId) async {
    final db = await _db;
    final row = await db.selectOne(
      sql:
          "SELECT COUNT(*) AS QTD FROM COLETAS_DETALHE "
          "WHERE ID_COLETA_ROTA = ? AND STATUS IN ('PENDENTE', 'EM_ANDAMENTO')",
      parameters: [rotaId],
    );
    return _toInt(row?['QTD']) ?? 0;
  }

  /// Encerra a rota, marcando o horário de término.
  ///
  /// O DATA_HORA_FIM só é gravado se ainda estiver vazio: reencerrar uma rota
  /// não deve reescrever quando ela terminou de fato.
  Future<bool> finalizarRota(int rotaId) async {
    final db = await _db;
    await db.execute(
      sql:
          "UPDATE COLETAS_ROTA SET STATUS = 'CONCLUIDA', "
          'DATA_HORA_FIM = COALESCE(DATA_HORA_FIM, CURRENT_TIMESTAMP) '
          'WHERE ID = ?',
      parameters: [rotaId],
    );
    return true;
  }

  /// Reabre uma rota concluída, para receber coleta remanejada ou corrigir um
  /// encerramento indevido. Limpa o término, já que ela voltou a correr.
  Future<bool> reabrirRota(int rotaId) async {
    final db = await _db;
    await db.execute(
      sql:
          "UPDATE COLETAS_ROTA SET STATUS = 'EM_ANDAMENTO', "
          'DATA_HORA_FIM = NULL WHERE ID = ?',
      parameters: [rotaId],
    );
    return true;
  }

  /// Reordena as paradas de uma rota (ORDEM_VISITA = posição na lista).
  Future<bool> atualizarOrdemParadas(List<int> paradaIdsEmOrdem) async {
    final db = await _db;
    for (int i = 0; i < paradaIdsEmOrdem.length; i++) {
      await db.execute(
        sql: 'UPDATE COLETAS_DETALHE SET ORDEM_VISITA = ? WHERE ID = ?',
        parameters: [i + 1, paradaIdsEmOrdem[i]],
      );
    }
    return true;
  }

  // ═════════════ CRUD PRODUTORES (TB_PESSOA) ═════════════
  String _tipoPessoaDoDoc(String cnpjCpf) {
    final n = cnpjCpf.replaceAll(RegExp(r'[^0-9]'), '');
    return n.length == 14 ? 'J' : 'F';
  }

  Future<PessoaModel?> criarProdutor(PessoaModel p) async {
    final db = await _db;
    final novoId = await _proximoId2('TB_PESSOA', 'PES_ID');
    await db.execute(
      sql: '''
        INSERT INTO TB_PESSOA
          (PES_ID, PES_TIPO_PESSOA, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, PES_CNPJ_CPF,
           PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, PES_CEP,
           PES_TELEFONE, PES_CELULAR, PES_EMAIL,
           PES_LATITUDE, PES_LONGITUDE, PES_HR_COLETA, PES_KM, PES_VOLUME_MEDIO, PES_ID_RESFRIADOR,
           PES_STATUS, PES_FORNECEDOR, PES_DT_CADASTRO)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'A', 'S', CURRENT_TIMESTAMP)
      ''',
      parameters: [
        novoId,
        _tipoPessoaDoDoc(p.cnpjCpf),
        p.rSocialNome,
        p.fantasiaApelido.isEmpty ? p.rSocialNome : p.fantasiaApelido,
        p.cnpjCpf,
        p.endereco,
        p.numero,
        p.complemento,
        p.bairro,
        p.cep,
        p.telefone,
        p.celular,
        p.email,
        p.latitude,
        p.longitude,
        p.horarioColeta,
        p.km,
        p.volumeMedio,
        p.resfriadorId,
      ],
    );
    p.id = novoId;
    return p;
  }

  Future<bool> atualizarProdutor(PessoaModel p) async {
    if (p.id == null) return false;
    final db = await _db;
    await db.execute(
      sql: '''
        UPDATE TB_PESSOA SET
          PES_RSOCIAL_NOME = ?,
          PES_FANTASIA_APELIDO = ?,
          PES_CNPJ_CPF = ?,
          PES_ENDERECO = ?,
          PES_NUMERO = ?,
          PES_COMPLEMENTO = ?,
          PES_BAIRRO = ?,
          PES_CEP = ?,
          PES_TELEFONE = ?,
          PES_CELULAR = ?,
          PES_EMAIL = ?,
          PES_LATITUDE = ?,
          PES_LONGITUDE = ?,
          PES_HR_COLETA = ?,
          PES_KM = ?,
          PES_VOLUME_MEDIO = ?,
          PES_ID_RESFRIADOR = ?,
          PES_STATUS = ?,
          PES_FORNECEDOR = 'S'
        WHERE PES_ID = ?
      ''',
      parameters: [
        p.rSocialNome,
        p.fantasiaApelido.isEmpty ? p.rSocialNome : p.fantasiaApelido,
        p.cnpjCpf,
        p.endereco,
        p.numero,
        p.complemento,
        p.bairro,
        p.cep,
        p.telefone,
        p.celular,
        p.email,
        p.latitude,
        p.longitude,
        p.horarioColeta,
        p.km,
        p.volumeMedio,
        p.resfriadorId,
        p.status.isEmpty ? 'A' : p.status,
        p.id,
      ],
    );
    return true;
  }

  /// Verifica se o produtor já tem movimentação (coletas ou vínculo em rota).
  Future<bool> produtorTemMovimentacao(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: '''
        SELECT
          (SELECT COUNT(*) FROM COLETAS_DETALHE WHERE ID_PRODUTOR = ?) +
          (SELECT COUNT(*) FROM COLETAS_ROTA WHERE ID_MOTORISTA = ?) AS QTD
        FROM RDB\$DATABASE
      ''',
      parameters: [id, id],
    );
    return (_toInt(row?['QTD']) ?? 0) > 0;
  }

  /// Exclusão lógica: marca o produtor como inativo (não remove do ERP).
  /// Bloqueada se o produtor já tiver movimentação.
  Future<bool> excluirProdutor(int id) async {
    if (await produtorTemMovimentacao(id)) {
      throw Exception(
        'O produtor possui movimentação (coletas/rotas) e não pode ser excluído.',
      );
    }
    final db = await _db;
    await db.execute(
      sql: "UPDATE TB_PESSOA SET PES_STATUS = 'I' WHERE PES_ID = ?",
      parameters: [id],
    );
    return true;
  }

  /// Próximo ID para tabelas cuja PK não é "ID" (ex.: PES_ID).
  Future<int> _proximoId2(String tabela, String coluna) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COALESCE(MAX($coluna),0)+1 AS NID FROM $tabela',
    );
    return _toInt(row?['NID']) ?? 1;
  }

  // ═════════════ CIDADES (TB_CIDADE) ═════════════
  /// Busca cidades por nome (para o campo de autocomplete do motorista).
  Future<List<OpcaoRef>> buscarCidades(String termo, {int limite = 30}) async {
    final db = await _db;
    final t = termo.trim().toUpperCase();
    if (t.isEmpty) return [];
    final rows = await db.selectAll(
      sql:
          '''
        SELECT FIRST $limite C.CID_ID, C.CID_NOME, E.EST_SIGLA
        FROM TB_CIDADE C
        LEFT JOIN TB_ESTADO E ON E.EST_ID = C.CID_ESTADO
        WHERE UPPER(C.CID_NOME) LIKE ?
        ORDER BY C.CID_NOME
      ''',
      parameters: ['%$t%'],
    );
    return rows.map(_cidadeRef).toList();
  }

  Future<OpcaoRef?> getCidadeById(int id) async {
    final db = await _db;
    final r = await db.selectOne(
      sql: '''
        SELECT C.CID_ID, C.CID_NOME, E.EST_SIGLA
        FROM TB_CIDADE C
        LEFT JOIN TB_ESTADO E ON E.EST_ID = C.CID_ESTADO
        WHERE C.CID_ID = ?
      ''',
      parameters: [id],
    );
    return r == null ? null : _cidadeRef(r);
  }

  OpcaoRef _cidadeRef(Map<String, dynamic> r) {
    final nome = _toStr(r['CID_NOME']) ?? '';
    final uf = _toStr(r['EST_SIGLA']) ?? '';
    return OpcaoRef(
      id: _toInt(r['CID_ID']) ?? 0,
      label: uf.isEmpty ? nome : '$nome - $uf',
    );
  }

  // ═════════════ MOTORISTAS (TB_PESSOA, PES_TRANSPORTADOR='S') ═════════════
  Future<List<MotoristaModel>> getMotoristas({String? status = 'A'}) async {
    final db = await _db;
    final filtro = (status != null && status.isNotEmpty)
        ? 'AND P.PES_STATUS = ?'
        : '';
    final rows = await db.selectAll(
      sql:
          '''
        SELECT P.PES_ID, P.PES_RSOCIAL_NOME, P.PES_FANTASIA_APELIDO, P.PES_CNPJ_CPF, P.PES_IE_RG,
               P.PES_TELEFONE, P.PES_CELULAR, P.PES_EMAIL, P.PES_ENDERECO, P.PES_NUMERO,
               P.PES_COMPLEMENTO, P.PES_BAIRRO, P.PES_CEP, P.PES_CNH, P.PES_STATUS,
               P.PES_CIDADE, C.CID_NOME
        FROM TB_PESSOA P
        LEFT JOIN TB_CIDADE C ON C.CID_ID = P.PES_CIDADE
        WHERE P.PES_TRANSPORTADOR = 'S' $filtro
        ORDER BY P.PES_RSOCIAL_NOME
      ''',
      parameters: (status != null && status.isNotEmpty) ? [status] : const [],
    );
    return rows
        .map(
          (r) => MotoristaModel(
            id: _toInt(r['PES_ID']),
            nome: _toStr(r['PES_RSOCIAL_NOME']),
            apelido: _toStr(r['PES_FANTASIA_APELIDO']),
            cpf: _toStr(r['PES_CNPJ_CPF']) ?? '',
            rg: _toStr(r['PES_IE_RG']) ?? '',
            telefone: _toStr(r['PES_TELEFONE']),
            celular: _toStr(r['PES_CELULAR']),
            email: _toStr(r['PES_EMAIL']),
            endereco: _toStr(r['PES_ENDERECO']),
            numero: _toStr(r['PES_NUMERO']),
            complemento: _toStr(r['PES_COMPLEMENTO']),
            bairro: _toStr(r['PES_BAIRRO']),
            cidadeId: _toInt(r['PES_CIDADE']),
            cidadeNome: _toStr(r['CID_NOME']),
            cep: _toStr(r['PES_CEP']),
            cnh: _toStr(r['PES_CNH']),
            status: _toStr(r['PES_STATUS']) ?? 'A',
          ),
        )
        .toList();
  }

  Future<MotoristaModel?> criarMotorista(MotoristaModel m) async {
    final db = await _db;
    final novoId = await _proximoId2('TB_PESSOA', 'PES_ID');
    final tipo = (m.cpf.replaceAll(RegExp(r'[^0-9]'), '').length == 14)
        ? 'J'
        : 'F';
    await db.execute(
      sql: '''
        INSERT INTO TB_PESSOA
          (PES_ID, PES_TIPO_PESSOA, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, PES_CNPJ_CPF, PES_IE_RG,
           PES_TELEFONE, PES_CELULAR, PES_EMAIL, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO,
           PES_BAIRRO, PES_CIDADE, PES_CEP, PES_CNH, PES_STATUS, PES_TRANSPORTADOR, PES_DT_CADASTRO)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'A', 'S', CURRENT_TIMESTAMP)
      ''',
      parameters: [
        novoId,
        tipo,
        m.nome,
        m.apelido,
        m.cpf,
        m.rg,
        m.telefone,
        m.celular,
        m.email,
        m.endereco,
        m.numero,
        m.complemento,
        m.bairro,
        m.cidadeId,
        m.cep,
        m.cnh,
      ],
    );
    m.id = novoId;
    return m;
  }

  Future<bool> atualizarMotorista(MotoristaModel m) async {
    if (m.id == null) return false;
    final db = await _db;
    await db.execute(
      sql: '''
        UPDATE TB_PESSOA SET
          PES_RSOCIAL_NOME = ?, PES_FANTASIA_APELIDO = ?, PES_CNPJ_CPF = ?, PES_IE_RG = ?,
          PES_TELEFONE = ?, PES_CELULAR = ?, PES_EMAIL = ?, PES_ENDERECO = ?, PES_NUMERO = ?,
          PES_COMPLEMENTO = ?, PES_BAIRRO = ?, PES_CIDADE = ?, PES_CEP = ?, PES_CNH = ?,
          PES_STATUS = ?, PES_TRANSPORTADOR = 'S'
        WHERE PES_ID = ?
      ''',
      parameters: [
        m.nome,
        m.apelido,
        m.cpf,
        m.rg,
        m.telefone,
        m.celular,
        m.email,
        m.endereco,
        m.numero,
        m.complemento,
        m.bairro,
        m.cidadeId,
        m.cep,
        m.cnh,
        m.status.isEmpty ? 'A' : m.status,
        m.id,
      ],
    );
    return true;
  }

  Future<bool> motoristaTemMovimentacao(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COUNT(*) AS QTD FROM COLETAS_ROTA WHERE ID_MOTORISTA = ?',
      parameters: [id],
    );
    return (_toInt(row?['QTD']) ?? 0) > 0;
  }

  Future<bool> excluirMotorista(int id) async {
    if (await motoristaTemMovimentacao(id)) {
      throw Exception(
        'O motorista possui rotas registradas e não pode ser excluído.',
      );
    }
    final db = await _db;
    await db.execute(
      sql: "UPDATE TB_PESSOA SET PES_STATUS = 'I' WHERE PES_ID = ?",
      parameters: [id],
    );
    return true;
  }

  // ═════════════ VEÍCULOS (TB_VEICULO) ═════════════
  Future<List<VeiculoModel>> getVeiculos({String? status}) async {
    final db = await _db;
    final filtro = (status != null && status.isNotEmpty)
        ? 'WHERE VEI_STATUS = ?'
        : '';
    final rows = await db.selectAll(
      sql:
          '''
        SELECT VEI_ID, VEI_PLACA, VEI_DESCRICAO, VEI_MARCA, VEI_MODELO,
               VEI_COR, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, VEI_STATUS
        FROM TB_VEICULO $filtro
        ORDER BY VEI_PLACA
      ''',
      parameters: (status != null && status.isNotEmpty) ? [status] : const [],
    );
    return rows
        .map(
          (r) => VeiculoModel(
            id: _toInt(r['VEI_ID']),
            placa: _toStr(r['VEI_PLACA']) ?? '',
            descricao: _toStr(r['VEI_DESCRICAO']) ?? '',
            marca: _toStr(r['VEI_MARCA']) ?? '',
            modelo: _toStr(r['VEI_MODELO']) ?? '',
            cor: _toStr(r['VEI_COR']) ?? '',
            tipo: _toStr(r['VEI_TIPO']) ?? 'C',
            renavam: _toStr(r['VEI_RENAVAM']) ?? '',
            chassi: _toStr(r['VEI_CHASSI']),
            status: _toStr(r['VEI_STATUS']) ?? 'A',
          ),
        )
        .toList();
  }

  /// Procura um veículo já cadastrado pela placa.
  ///
  /// É o que sustenta a consulta por placa das telas: em vez de cadastrar o
  /// mesmo carro duas vezes, quem digita uma placa conhecida recebe o registro
  /// que já existe na base e passa a editá-lo. A comparação ignora maiúsculas,
  /// espaços e o hífero do padrão antigo (ABC-1234 acha ABC1234).
  Future<VeiculoModel?> buscarVeiculoPorPlaca(String placa) async {
    final alvo = normalizarPlaca(placa);
    if (alvo.isEmpty) return null;
    // O filtro roda em memória porque a base guarda a placa com formatações
    // diferentes conforme a época do cadastro, e nenhum LIKE cobre todas.
    final todos = await getVeiculos();
    for (final v in todos) {
      if (normalizarPlaca(v.placa) == alvo) return v;
    }
    return null;
  }

  /// Deixa a placa só com letras e números, em maiúsculas.
  static String normalizarPlaca(String placa) =>
      placa.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<VeiculoModel?> criarVeiculo(VeiculoModel v) async {
    final db = await _db;
    final novoId = await _proximoId2('TB_VEICULO', 'VEI_ID');
    await db.execute(
      sql: '''
        INSERT INTO TB_VEICULO
          (VEI_ID, VEI_EMPRESA, VEI_PLACA, VEI_DESCRICAO, VEI_MARCA, VEI_MODELO, VEI_COR, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI, VEI_STATUS)
        VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?, 'A')
      ''',
      parameters: [
        novoId,
        v.placa,
        v.descricao,
        v.marca,
        v.modelo,
        v.cor,
        v.tipo,
        v.renavam,
        v.chassi,
      ],
    );
    v.id = novoId;
    return v;
  }

  Future<bool> atualizarVeiculo(VeiculoModel v) async {
    if (v.id == null) return false;
    final db = await _db;
    await db.execute(
      sql: '''
        UPDATE TB_VEICULO SET
          VEI_PLACA = ?, VEI_DESCRICAO = ?, VEI_MARCA = ?, VEI_MODELO = ?,
          VEI_COR = ?, VEI_TIPO = ?, VEI_RENAVAM = ?, VEI_CHASSI = ?,
          VEI_STATUS = ?
        WHERE VEI_ID = ?
      ''',
      parameters: [
        v.placa,
        v.descricao,
        v.marca,
        v.modelo,
        v.cor,
        v.tipo,
        v.renavam,
        v.chassi,
        v.status.isEmpty ? 'A' : v.status,
        v.id,
      ],
    );
    return true;
  }

  Future<bool> veiculoTemMovimentacao(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COUNT(*) AS QTD FROM COLETAS_ROTA WHERE ID_VEICULO = ?',
      parameters: [id],
    );
    return (_toInt(row?['QTD']) ?? 0) > 0;
  }

  Future<bool> excluirVeiculo(int id) async {
    if (await veiculoTemMovimentacao(id)) {
      throw Exception(
        'O veículo possui rotas registradas e não pode ser excluído.',
      );
    }
    final db = await _db;
    await db.execute(
      sql: "UPDATE TB_VEICULO SET VEI_STATUS = 'I' WHERE VEI_ID = ?",
      parameters: [id],
    );
    return true;
  }

  // ═════════════ CONTAS / CAIXA (TB_CONTA) ═════════════
  /// Lista as contas financeiras (caixa e bancos) ativas.
  Future<List<ContaRef>> getContas() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT CNT_ID, CNT_DESCRICAO, CNT_TIPO
        FROM TB_CONTA
        WHERE (CNT_STATUS IS NULL OR CNT_STATUS = 'A')
        ORDER BY CNT_TIPO, CNT_DESCRICAO
      ''',
    );
    return rows
        .map(
          (r) => ContaRef(
            id: _toInt(r['CNT_ID']) ?? 0,
            descricao: _toStr(r['CNT_DESCRICAO']) ?? '',
            tipo: _toStr(r['CNT_TIPO']) ?? 'C',
          ),
        )
        .toList();
  }

  /// Saldo de cada conta = soma das entradas (C) menos as saídas (D).
  Future<List<SaldoConta>> getSaldosPorConta() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT C.CNT_ID, C.CNT_DESCRICAO, C.CNT_TIPO,
               COALESCE(SUM(CASE WHEN M.MOV_TIPO = 'C' THEN M.MOV_VALOR
                                 WHEN M.MOV_TIPO = 'D' THEN -M.MOV_VALOR
                                 ELSE 0 END), 0) AS SALDO
        FROM TB_CONTA C
        LEFT JOIN TB_MOVIMENTO_CONTA M ON M.MOV_CONTA = C.CNT_ID
        WHERE (C.CNT_STATUS IS NULL OR C.CNT_STATUS = 'A')
        GROUP BY C.CNT_ID, C.CNT_DESCRICAO, C.CNT_TIPO
        ORDER BY C.CNT_TIPO, C.CNT_DESCRICAO
      ''',
    );
    return rows
        .map(
          (r) => SaldoConta(
            id: _toInt(r['CNT_ID']) ?? 0,
            descricao: _toStr(r['CNT_DESCRICAO']) ?? '',
            tipo: _toStr(r['CNT_TIPO']) ?? 'C',
            saldo: _toDouble(r['SALDO']) ?? 0,
          ),
        )
        .toList();
  }

  // ═════════════ MOVIMENTO DE CONTA (TB_MOVIMENTO_CONTA) ═════════════
  Future<List<MovimentoModel>> getMovimentos({
    int? contaId,
    String? tipo,
  }) async {
    final db = await _db;
    final where = <String>[];
    final params = <dynamic>[];
    if (contaId != null) {
      where.add('M.MOV_CONTA = ?');
      params.add(contaId);
    }
    if (tipo != null && tipo.isNotEmpty) {
      where.add('M.MOV_TIPO = ?');
      params.add(tipo);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final rows = await db.selectAll(
      sql:
          '''
        SELECT M.MOV_ID, M.MOV_TIPO, M.MOV_STATUS, M.MOV_COMPENSADO, M.MOV_ORIGEM,
               M.MOV_ID_ORIGEM, M.MOV_CONTA, M.MOV_VALOR, M.MOV_DT_EMISSAO,
               M.MOV_DT_AGENDADO, M.MOV_DT_COMPENSADO, M.MOV_HISTORICO, M.MOV_DT_LANCAMENTO,
               C.CNT_DESCRICAO
        FROM TB_MOVIMENTO_CONTA M
        LEFT JOIN TB_CONTA C ON C.CNT_ID = M.MOV_CONTA
        $whereSql
        ORDER BY M.MOV_DT_EMISSAO DESC, M.MOV_ID DESC
      ''',
      parameters: params,
    );

    String soData(String? iso) => (iso ?? '').split('T').first;

    return rows
        .map(
          (r) => MovimentoModel(
            id: _toInt(r['MOV_ID']),
            tipo: _toStr(r['MOV_TIPO']) ?? 'C',
            status: _toStr(r['MOV_STATUS']) ?? 'P',
            compensado: _toStr(r['MOV_COMPENSADO']) ?? 'S',
            origem: _toStr(r['MOV_ORIGEM']) ?? '',
            idOrigem: _toInt(r['MOV_ID_ORIGEM']),
            conta: _toInt(r['MOV_CONTA']) ?? 0,
            contaNome: _toStr(r['CNT_DESCRICAO']),
            valor: _toDouble(r['MOV_VALOR']) ?? 0,
            dtEmissao: soData(_toStr(r['MOV_DT_EMISSAO'])),
            dtAgendado: _toStr(r['MOV_DT_AGENDADO']),
            dtCompensado: _toStr(r['MOV_DT_COMPENSADO']),
            historico: _toStr(r['MOV_HISTORICO']) ?? '',
            dtLancamento: _toStr(r['MOV_DT_LANCAMENTO']),
          ),
        )
        .toList();
  }

  Future<MovimentoModel?> criarMovimento(MovimentoModel mov) async {
    final db = await _db;
    final novoId = await _proximoId2('TB_MOVIMENTO_CONTA', 'MOV_ID');
    final dtEmissao = DateTime.tryParse(mov.dtEmissao) ?? DateTime.now();
    await db.execute(
      sql: '''
        INSERT INTO TB_MOVIMENTO_CONTA
          (MOV_ID, MOV_EMPRESA, MOV_TIPO, MOV_STATUS, MOV_COMPENSADO, MOV_ORIGEM,
           MOV_ID_ORIGEM, MOV_CONTA, MOV_VALOR, MOV_DT_EMISSAO, MOV_HISTORICO, MOV_DT_LANCAMENTO)
        VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      parameters: [
        novoId,
        mov.tipo,
        mov.status,
        mov.compensado,
        mov.origem,
        mov.idOrigem,
        mov.conta,
        mov.valor,
        dtEmissao,
        mov.historico,
      ],
    );
    return mov.id == null
        ? MovimentoModel(
            id: novoId,
            tipo: mov.tipo,
            status: mov.status,
            compensado: mov.compensado,
            origem: mov.origem,
            idOrigem: mov.idOrigem,
            conta: mov.conta,
            contaNome: mov.contaNome,
            valor: mov.valor,
            dtEmissao: mov.dtEmissao,
            historico: mov.historico,
          )
        : mov;
  }

  // ═════════════ RESFRIADORES (TB_RESFRIADOR) ═════════════
  Future<List<ResfriadorModel>> getResfriadores({String? status}) async {
    final db = await _db;
    final filtro = (status != null && status.isNotEmpty)
        ? 'WHERE RES_STATUS = ?'
        : '';
    final rows = await db.selectAll(
      sql:
          '''
        SELECT RES_ID, RES_NUMERO_ID, RES_MARCA_MODELO, RES_CAPACIDADE_LITROS,
               RES_ANO_FABRICACAO, RES_ULTIMA_MANUTENCAO, RES_STATUS
        FROM TB_RESFRIADOR $filtro
        ORDER BY RES_NUMERO_ID
      ''',
      parameters: (status != null && status.isNotEmpty) ? [status] : const [],
    );
    return rows
        .map(
          (r) => ResfriadorModel(
            id: _toInt(r['RES_ID']),
            numeroId: _toStr(r['RES_NUMERO_ID']) ?? '',
            marcaModelo: _toStr(r['RES_MARCA_MODELO']) ?? '',
            capacidadeLitros: _toDouble(r['RES_CAPACIDADE_LITROS']) ?? 0,
            anoFabricacao: _toInt(r['RES_ANO_FABRICACAO']),
            ultimaManutencao: (_toStr(r['RES_ULTIMA_MANUTENCAO']) ?? '')
                .split('T')
                .first,
            status: _toStr(r['RES_STATUS']) ?? 'ATIVO',
          ),
        )
        .toList();
  }

  Future<ResfriadorModel?> criarResfriador(ResfriadorModel r) async {
    final db = await _db;
    final novoId = await _proximoId2('TB_RESFRIADOR', 'RES_ID');
    final manut = (r.ultimaManutencao != null && r.ultimaManutencao!.isNotEmpty)
        ? DateTime.tryParse(r.ultimaManutencao!)
        : null;
    await db.execute(
      sql: '''
        INSERT INTO TB_RESFRIADOR
          (RES_ID, RES_NUMERO_ID, RES_MARCA_MODELO, RES_CAPACIDADE_LITROS,
           RES_ANO_FABRICACAO, RES_ULTIMA_MANUTENCAO, RES_STATUS)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      parameters: [
        novoId,
        r.numeroId,
        r.marcaModelo,
        r.capacidadeLitros,
        r.anoFabricacao,
        manut,
        r.status.isEmpty ? 'ATIVO' : r.status,
      ],
    );
    r.id = novoId;
    return r;
  }

  Future<bool> atualizarResfriador(ResfriadorModel r) async {
    if (r.id == null) return false;
    final db = await _db;
    final manut = (r.ultimaManutencao != null && r.ultimaManutencao!.isNotEmpty)
        ? DateTime.tryParse(r.ultimaManutencao!)
        : null;
    await db.execute(
      sql: '''
        UPDATE TB_RESFRIADOR SET
          RES_NUMERO_ID = ?, RES_MARCA_MODELO = ?, RES_CAPACIDADE_LITROS = ?,
          RES_ANO_FABRICACAO = ?, RES_ULTIMA_MANUTENCAO = ?, RES_STATUS = ?
        WHERE RES_ID = ?
      ''',
      parameters: [
        r.numeroId,
        r.marcaModelo,
        r.capacidadeLitros,
        r.anoFabricacao,
        manut,
        r.status.isEmpty ? 'ATIVO' : r.status,
        r.id,
      ],
    );
    return true;
  }

  Future<bool> resfriadorTemVinculo(int id) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COUNT(*) AS QTD FROM TB_PESSOA WHERE PES_ID_RESFRIADOR = ?',
      parameters: [id],
    );
    return (_toInt(row?['QTD']) ?? 0) > 0;
  }

  Future<bool> excluirResfriador(int id) async {
    if (await resfriadorTemVinculo(id)) {
      throw Exception(
        'O resfriador está vinculado a um produtor e não pode ser excluído.',
      );
    }
    final db = await _db;
    await db.execute(
      sql: 'DELETE FROM TB_RESFRIADOR WHERE RES_ID = ?',
      parameters: [id],
    );
    return true;
  }

  Future<bool> atualizarMovimento(MovimentoModel mov) async {
    if (mov.id == null) return false;
    final db = await _db;
    final dtEmissao = DateTime.tryParse(mov.dtEmissao);
    await db.execute(
      sql: '''
        UPDATE TB_MOVIMENTO_CONTA SET
          MOV_TIPO = ?, MOV_STATUS = ?, MOV_CONTA = ?, MOV_VALOR = ?,
          MOV_DT_EMISSAO = COALESCE(?, MOV_DT_EMISSAO), MOV_HISTORICO = ?
        WHERE MOV_ID = ?
      ''',
      parameters: [
        mov.tipo,
        mov.status,
        mov.conta,
        mov.valor,
        dtEmissao,
        mov.historico,
        mov.id,
      ],
    );
    return true;
  }

  Future<bool> excluirMovimento(int id) async {
    final db = await _db;
    await db.execute(
      sql: 'DELETE FROM TB_MOVIMENTO_CONTA WHERE MOV_ID = ?',
      parameters: [id],
    );
    return true;
  }
}
