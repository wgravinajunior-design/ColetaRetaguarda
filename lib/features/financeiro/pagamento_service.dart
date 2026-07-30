import '../core/database/db_connection.dart';

/// Uma linha da folha: o que um produtor tem a receber no período.
class LinhaFolha {
  final int produtorId;
  final String produtorNome;
  final double litros;
  final double precoLitro;

  /// Descontos em aberto do produtor, somados até o fim do período.
  double descontos;

  LinhaFolha({
    required this.produtorId,
    required this.produtorNome,
    required this.litros,
    required this.precoLitro,
    this.descontos = 0,
  });

  double get bruto => litros * precoLitro;

  /// Nunca negativo: um desconto maior que o bruto fica devendo para a próxima
  /// folha em vez de virar valor a pagar com sinal trocado.
  double get liquido {
    final v = bruto - descontos;
    return v < 0 ? 0 : v;
  }

  bool get semPreco => precoLitro <= 0;
}

/// Um pagamento já lançado, como aparece no histórico.
class PagamentoResumo {
  final int id;
  final String tipo; // 'DEPOSITO' ou 'FOLHA'
  final String? dtInicio;
  final String? dtFim;
  final double valorTotal;
  final String observacao;
  final String? dtLancamento;

  PagamentoResumo({
    required this.id,
    required this.tipo,
    this.dtInicio,
    this.dtFim,
    required this.valorTotal,
    this.observacao = '',
    this.dtLancamento,
  });

  bool get ehDeposito => tipo.toUpperCase() == 'DEPOSITO';
}

/// Um desconto lançado para um produtor.
class DescontoModel {
  final int? id;
  final int produtorId;
  final String produtorNome;
  final String data;
  final double valor;
  final String descricao;

  /// Folha em que este desconto foi abatido. Nulo enquanto está em aberto.
  final int? pagamentoId;

  DescontoModel({
    this.id,
    required this.produtorId,
    this.produtorNome = '',
    required this.data,
    required this.valor,
    this.descricao = '',
    this.pagamentoId,
  });

  bool get emAberto => pagamentoId == null;
}

/// Depósitos do laticínio, folha de pagamento dos produtores e os descontos
/// que entram nela.
///
/// O valor de cada produtor sai dos litros que ele entregou no período
/// multiplicados pelo preço por litro do cadastro dele — o depósito do
/// laticínio entra como conferência do total, não como base do rateio.
class PagamentoService {
  static final PagamentoService _instance = PagamentoService._internal();
  factory PagamentoService() => _instance;
  PagamentoService._internal();

  Future<dynamic> get _db async => DbConnection().db;

  static String _texto(dynamic v) => v == null ? '' : '$v'.trim();
  static double _numero(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v'.replaceAll(',', '.').trim()) ?? 0;
  }

  static String _dia(dynamic v) => _texto(v).split('T').first.split(' ').first;

  Future<int> _proximoId(String tabela, String coluna) async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COALESCE(MAX($coluna),0)+1 AS NID FROM $tabela',
    );
    return (row?['NID'] as int?) ?? 1;
  }

  // ── Folha ────────────────────────────────────────────────────────────────

  /// Monta a folha do período, sem gravar nada.
  ///
  /// Só entram coletas confirmadas: recusada e adiada não geraram leite, e
  /// pendente ainda pode mudar até o motorista fechar a rota.
  Future<List<LinhaFolha>> montarFolha(DateTime inicio, DateTime fim) async {
    final db = await _db;

    final rows = await db.selectAll(
      sql: '''
        SELECT D.ID_PRODUTOR,
               P.PES_RSOCIAL_NOME,
               COALESCE(P.PES_PRECO_LITRO, 0) AS PRECO,
               SUM(COALESCE(D.VOLUME_COLETADO_LITROS, 0)) AS LITROS
          FROM COLETAS_DETALHE D
          JOIN COLETAS_ROTA R ON R.ID = D.ID_COLETA_ROTA
          LEFT JOIN TB_PESSOA P ON P.PES_ID = D.ID_PRODUTOR
         WHERE R.DATA_COLETA BETWEEN ? AND ?
           AND D.STATUS = 'CONFIRMADO'
         GROUP BY D.ID_PRODUTOR, P.PES_RSOCIAL_NOME, P.PES_PRECO_LITRO
         ORDER BY P.PES_RSOCIAL_NOME
      ''',
      parameters: [inicio, fim],
    );

    final linhas = rows
        .map<LinhaFolha>(
          (r) => LinhaFolha(
            produtorId: (r['ID_PRODUTOR'] as int?) ?? 0,
            produtorNome: _texto(r['PES_RSOCIAL_NOME']),
            litros: _numero(r['LITROS']),
            precoLitro: _numero(r['PRECO']),
          ),
        )
        .toList();

    // Descontos ainda não abatidos, até o fim do período.
    final descontos = await db.selectAll(
      sql: '''
        SELECT DSC_PRODUTOR_ID, SUM(COALESCE(DSC_VALOR,0)) AS TOTAL
          FROM COLETAS_DESCONTO
         WHERE DSC_PAGAMENTO_ID IS NULL
           AND DSC_DATA <= ?
         GROUP BY DSC_PRODUTOR_ID
      ''',
      parameters: [fim],
    );

    final porProdutor = <int, double>{
      for (final d in descontos)
        ((d['DSC_PRODUTOR_ID'] as int?) ?? 0): _numero(d['TOTAL']),
    };
    for (final l in linhas) {
      l.descontos = porProdutor[l.produtorId] ?? 0;
    }

    return linhas;
  }

  /// Fecha a folha: grava o cabeçalho, uma linha por produtor, e marca os
  /// descontos do período como abatidos nela.
  ///
  /// Os valores vão gravados, não recalculados na leitura: preço e volume
  /// mudam, e uma folha fechada tem de continuar batendo com o que foi pago.
  Future<int> salvarFolha({
    required DateTime inicio,
    required DateTime fim,
    required List<LinhaFolha> linhas,
    String observacao = '',
  }) async {
    final db = await _db;
    final pagamentoId = await _proximoId('COLETAS_PAGAMENTO', 'PAG_ID');
    final total = linhas.fold<double>(0, (s, l) => s + l.liquido);

    await db.execute(
      sql: '''
        INSERT INTO COLETAS_PAGAMENTO
          (PAG_ID, PAG_TIPO, PAG_DT_INICIO, PAG_DT_FIM, PAG_VALOR_TOTAL,
           PAG_OBSERVACAO, PAG_DT_LANCAMENTO)
        VALUES (?, 'FOLHA', ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      parameters: [pagamentoId, inicio, fim, total, observacao],
    );

    var itemId = await _proximoId('COLETAS_PAGAMENTO_ITEM', 'ITE_ID');
    for (final l in linhas) {
      await db.execute(
        sql: '''
          INSERT INTO COLETAS_PAGAMENTO_ITEM
            (ITE_ID, ITE_PAGAMENTO_ID, ITE_PRODUTOR_ID, ITE_LITROS,
             ITE_PRECO_LITRO, ITE_VALOR_BRUTO, ITE_DESCONTOS, ITE_VALOR_LIQUIDO)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        parameters: [
          itemId++,
          pagamentoId,
          l.produtorId,
          l.litros,
          l.precoLitro,
          l.bruto,
          l.descontos,
          l.liquido,
        ],
      );
    }

    // Fecha os descontos usados. Sem isto eles voltariam na folha seguinte.
    await db.execute(
      sql: '''
        UPDATE COLETAS_DESCONTO SET DSC_PAGAMENTO_ID = ?
         WHERE DSC_PAGAMENTO_ID IS NULL AND DSC_DATA <= ?
      ''',
      parameters: [pagamentoId, fim],
    );

    return pagamentoId;
  }

  // ── Depósito do laticínio ────────────────────────────────────────────────

  Future<int> salvarDeposito({
    required DateTime data,
    required double valor,
    String observacao = '',
  }) async {
    final db = await _db;
    final id = await _proximoId('COLETAS_PAGAMENTO', 'PAG_ID');
    await db.execute(
      sql: '''
        INSERT INTO COLETAS_PAGAMENTO
          (PAG_ID, PAG_TIPO, PAG_DT_INICIO, PAG_DT_FIM, PAG_VALOR_TOTAL,
           PAG_OBSERVACAO, PAG_DT_LANCAMENTO)
        VALUES (?, 'DEPOSITO', ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      parameters: [id, data, data, valor, observacao],
    );
    return id;
  }

  // ── Histórico ────────────────────────────────────────────────────────────

  Future<List<PagamentoResumo>> historico({int limite = 100}) async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT FIRST $limite PAG_ID, PAG_TIPO, PAG_DT_INICIO, PAG_DT_FIM,
               PAG_VALOR_TOTAL, PAG_OBSERVACAO, PAG_DT_LANCAMENTO
          FROM COLETAS_PAGAMENTO
         ORDER BY PAG_DT_LANCAMENTO DESC, PAG_ID DESC
      ''',
    );
    return rows
        .map<PagamentoResumo>(
          (r) => PagamentoResumo(
            id: (r['PAG_ID'] as int?) ?? 0,
            tipo: _texto(r['PAG_TIPO']),
            dtInicio: _dia(r['PAG_DT_INICIO']),
            dtFim: _dia(r['PAG_DT_FIM']),
            valorTotal: _numero(r['PAG_VALOR_TOTAL']),
            observacao: _texto(r['PAG_OBSERVACAO']),
            dtLancamento: _dia(r['PAG_DT_LANCAMENTO']),
          ),
        )
        .toList();
  }

  /// Linhas de uma folha já fechada.
  Future<List<LinhaFolha>> itensDaFolha(int pagamentoId) async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT I.ITE_PRODUTOR_ID, I.ITE_LITROS, I.ITE_PRECO_LITRO,
               I.ITE_DESCONTOS, P.PES_RSOCIAL_NOME
          FROM COLETAS_PAGAMENTO_ITEM I
          LEFT JOIN TB_PESSOA P ON P.PES_ID = I.ITE_PRODUTOR_ID
         WHERE I.ITE_PAGAMENTO_ID = ?
         ORDER BY P.PES_RSOCIAL_NOME
      ''',
      parameters: [pagamentoId],
    );
    return rows
        .map<LinhaFolha>(
          (r) => LinhaFolha(
            produtorId: (r['ITE_PRODUTOR_ID'] as int?) ?? 0,
            produtorNome: _texto(r['PES_RSOCIAL_NOME']),
            litros: _numero(r['ITE_LITROS']),
            precoLitro: _numero(r['ITE_PRECO_LITRO']),
            descontos: _numero(r['ITE_DESCONTOS']),
          ),
        )
        .toList();
  }

  // ── Descontos ────────────────────────────────────────────────────────────

  Future<List<DescontoModel>> descontos({bool somenteAbertos = true}) async {
    final db = await _db;
    final filtro = somenteAbertos ? 'WHERE D.DSC_PAGAMENTO_ID IS NULL' : '';
    final rows = await db.selectAll(
      sql: '''
        SELECT D.DSC_ID, D.DSC_PRODUTOR_ID, D.DSC_DATA, D.DSC_VALOR,
               D.DSC_DESCRICAO, D.DSC_PAGAMENTO_ID, P.PES_RSOCIAL_NOME
          FROM COLETAS_DESCONTO D
          LEFT JOIN TB_PESSOA P ON P.PES_ID = D.DSC_PRODUTOR_ID
         $filtro
         ORDER BY D.DSC_DATA DESC, D.DSC_ID DESC
      ''',
    );
    return rows
        .map<DescontoModel>(
          (r) => DescontoModel(
            id: r['DSC_ID'] as int?,
            produtorId: (r['DSC_PRODUTOR_ID'] as int?) ?? 0,
            produtorNome: _texto(r['PES_RSOCIAL_NOME']),
            data: _dia(r['DSC_DATA']),
            valor: _numero(r['DSC_VALOR']),
            descricao: _texto(r['DSC_DESCRICAO']),
            pagamentoId: r['DSC_PAGAMENTO_ID'] as int?,
          ),
        )
        .toList();
  }

  Future<int> criarDesconto({
    required int produtorId,
    required DateTime data,
    required double valor,
    String descricao = '',
  }) async {
    final db = await _db;
    final id = await _proximoId('COLETAS_DESCONTO', 'DSC_ID');
    await db.execute(
      sql: '''
        INSERT INTO COLETAS_DESCONTO
          (DSC_ID, DSC_PRODUTOR_ID, DSC_DATA, DSC_VALOR, DSC_DESCRICAO)
        VALUES (?, ?, ?, ?, ?)
      ''',
      parameters: [id, produtorId, data, valor, descricao],
    );
    return id;
  }

  /// Só apaga o que ainda não entrou em folha: excluir um desconto já abatido
  /// deixaria a folha fechada sem como explicar o valor que ela cobrou.
  Future<bool> excluirDesconto(int id) async {
    final db = await _db;
    await db.execute(
      sql: 'DELETE FROM COLETAS_DESCONTO '
          'WHERE DSC_ID = ? AND DSC_PAGAMENTO_ID IS NULL',
      parameters: [id],
    );
    return true;
  }
}
