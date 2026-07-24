import 'package:fbdb/fbdb.dart';
import '../../core/database/db_connection.dart';
import '../models/relatorio.dart';

/// Executa as consultas dos relatórios direto no Firebird.
///
/// Os repositórios existentes não aceitam filtro por período, que é o recorte
/// mais pedido aqui — daí o SQL próprio, montado com parâmetros.
class RelatorioService {
  Future<FbDb> get _db => DbConnection().db;

  static String data(DateTime? d) {
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year}';
  }

  static String dinheiro(num v) {
    final negativo = v < 0;
    final s = v.abs().toStringAsFixed(2).replaceAll('.', ',');
    // Separador de milhar da direita para a esquerda.
    final partes = s.split(',');
    final inteiro = partes[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    return '${negativo ? '-' : ''}R\$ $inteiro,${partes[1]}';
  }

  static String numero(num v, {int casas = 0}) =>
      v.toStringAsFixed(casas).replaceAll('.', ',');

  static String _statusColeta(String? s) => switch (s) {
    'CONFIRMADO' || 'C' => 'Confirmada',
    'RECUSADO' || 'R' => 'Recusada',
    'ADIADO' || 'A' => 'Adiada',
    'EM_ANDAMENTO' || 'E' => 'Em andamento',
    _ => 'Pendente',
  };

  static String _dataHora(dynamic v) {
    if (v is DateTime) {
      String dois(int n) => n.toString().padLeft(2, '0');
      return '${dois(v.day)}/${dois(v.month)}/${v.year}';
    }
    return v?.toString().split(' ').first ?? '';
  }

  /// Roda o relatório pedido com os filtros informados.
  Future<ResultadoRelatorio> executar(
    DefinicaoRelatorio def,
    ValoresFiltro f,
  ) async {
    return switch (def.id) {
      'coletas_periodo' => _coletasPeriodo(f),
      'producao_produtor' => _producaoProdutor(f),
      'rotas_realizadas' => _rotasRealizadas(f),
      'qualidade_temperatura' => _alertasTemperatura(f),
      'movimentacoes' => _movimentacoes(f),
      'saldos_conta' => _saldosConta(),
      'resumo_plano_contas' => _resumoPlanoContas(f),
      'produtores' => _produtores(f),
      'frota' => _frota(f),
      _ => const ResultadoRelatorio(colunas: [], linhas: []),
    };
  }

  /// Recorte de período aplicado sobre uma coluna de data.
  (String, List<dynamic>) _periodo(ValoresFiltro f, String coluna) {
    final where = <String>[];
    final params = <dynamic>[];
    if (f.inicio != null) {
      where.add('$coluna >= ?');
      params.add(DateTime(f.inicio!.year, f.inicio!.month, f.inicio!.day));
    }
    if (f.fim != null) {
      where.add('$coluna <= ?');
      params.add(DateTime(f.fim!.year, f.fim!.month, f.fim!.day, 23, 59, 59));
    }
    return (where.join(' AND '), params);
  }

  String _descreverPeriodo(ValoresFiltro f) {
    if (f.inicio == null && f.fim == null) return 'Todo o período';
    if (f.inicio != null && f.fim != null) {
      return 'De ${data(f.inicio)} a ${data(f.fim)}';
    }
    return f.inicio != null
        ? 'A partir de ${data(f.inicio)}'
        : 'Até ${data(f.fim)}';
  }

  // ══════════════════════════ COLETA ══════════════════════════

  Future<ResultadoRelatorio> _coletasPeriodo(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'D.DATA_HORA_REGISTRO');
    final where = <String>[if (wPeriodo.isNotEmpty) wPeriodo];
    if (f.status != null && f.status!.isNotEmpty) {
      where.add('D.STATUS = ?');
      params.add(f.status);
    }

    final rows = await db.selectAll(
      sql:
          '''
        SELECT D.DATA_HORA_REGISTRO, P.PES_RSOCIAL_NOME, R.NOME AS ROTA,
               D.VOLUME_COLETADO_LITROS, D.TEMPERATURA_LEITE_C, D.STATUS
        FROM COLETAS_DETALHE D
        LEFT JOIN TB_PESSOA P ON P.PES_ID = D.ID_PRODUTOR
        LEFT JOIN COLETAS_ROTA R ON R.ID = D.ID_COLETA_ROTA
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY D.DATA_HORA_REGISTRO DESC
      ''',
      parameters: params,
    );

    var litros = 0.0;
    final temps = <double>[];
    final linhas = rows.map((r) {
      final v = (r['VOLUME_COLETADO_LITROS'] as num?)?.toDouble() ?? 0;
      final t = (r['TEMPERATURA_LEITE_C'] as num?)?.toDouble();
      final st = r['STATUS']?.toString();
      if (st == 'CONFIRMADO') {
        litros += v;
        if (t != null && t > 0) temps.add(t);
      }
      return [
        _dataHora(r['DATA_HORA_REGISTRO']),
        r['PES_RSOCIAL_NOME']?.toString() ?? '',
        r['ROTA']?.toString() ?? '',
        numero(v),
        t == null ? '' : numero(t, casas: 1),
        _statusColeta(st),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Data', tipo: TipoColuna.data),
        ColunaRelatorio('Produtor', flex: 3),
        ColunaRelatorio('Rota', flex: 2),
        ColunaRelatorio('Litros', tipo: TipoColuna.numero),
        ColunaRelatorio('Temp. °C', tipo: TipoColuna.numero),
        ColunaRelatorio('Situação'),
      ],
      linhas: linhas,
      totais: {
        'Coletas': '${rows.length}',
        'Total coletado': '${numero(litros)} L',
        if (temps.isNotEmpty)
          'Temperatura média':
              '${numero(temps.reduce((a, b) => a + b) / temps.length, casas: 1)} °C',
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  Future<ResultadoRelatorio> _producaoProdutor(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'D.DATA_HORA_REGISTRO');
    final where = <String>["D.STATUS = 'CONFIRMADO'"];
    if (wPeriodo.isNotEmpty) where.add(wPeriodo);

    final rows = await db.selectAll(
      sql:
          '''
        SELECT P.PES_RSOCIAL_NOME, COUNT(*) AS QTD,
               SUM(D.VOLUME_COLETADO_LITROS) AS LITROS,
               AVG(D.TEMPERATURA_LEITE_C) AS TEMP
        FROM COLETAS_DETALHE D
        LEFT JOIN TB_PESSOA P ON P.PES_ID = D.ID_PRODUTOR
        WHERE ${where.join(' AND ')}
        GROUP BY P.PES_RSOCIAL_NOME
        ORDER BY SUM(D.VOLUME_COLETADO_LITROS) DESC
      ''',
      parameters: params,
    );

    var total = 0.0;
    final linhas = rows.map((r) {
      final litros = (r['LITROS'] as num?)?.toDouble() ?? 0;
      final qtd = (r['QTD'] as num?)?.toInt() ?? 0;
      final temp = (r['TEMP'] as num?)?.toDouble();
      total += litros;
      return [
        r['PES_RSOCIAL_NOME']?.toString() ?? '',
        '$qtd',
        numero(litros),
        qtd > 0 ? numero(litros / qtd) : '0',
        temp == null ? '' : numero(temp, casas: 1),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Produtor', flex: 4),
        ColunaRelatorio('Coletas', tipo: TipoColuna.numero),
        ColunaRelatorio('Total (L)', tipo: TipoColuna.numero),
        ColunaRelatorio('Média (L)', tipo: TipoColuna.numero),
        ColunaRelatorio('Temp. média', tipo: TipoColuna.numero),
      ],
      linhas: linhas,
      totais: {
        'Produtores': '${rows.length}',
        'Total geral': '${numero(total)} L',
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  Future<ResultadoRelatorio> _rotasRealizadas(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'R.DATA_COLETA');
    final where = <String>[if (wPeriodo.isNotEmpty) wPeriodo];
    if (f.status != null && f.status!.isNotEmpty) {
      where.add('R.STATUS = ?');
      params.add(f.status);
    }

    final rows = await db.selectAll(
      sql:
          '''
        SELECT R.NOME, R.DATA_COLETA, R.STATUS,
               M.PES_RSOCIAL_NOME AS MOTORISTA, V.VEI_PLACA,
               (SELECT COUNT(*) FROM COLETAS_DETALHE D WHERE D.ID_COLETA_ROTA = R.ID) AS PARADAS,
               (SELECT COUNT(*) FROM COLETAS_DETALHE D WHERE D.ID_COLETA_ROTA = R.ID
                  AND D.STATUS = 'CONFIRMADO') AS FEITAS,
               (SELECT COALESCE(SUM(D.VOLUME_COLETADO_LITROS),0) FROM COLETAS_DETALHE D
                  WHERE D.ID_COLETA_ROTA = R.ID AND D.STATUS = 'CONFIRMADO') AS LITROS
        FROM COLETAS_ROTA R
        LEFT JOIN TB_PESSOA M ON M.PES_ID = R.ID_MOTORISTA
        LEFT JOIN TB_VEICULO V ON V.VEI_ID = R.ID_VEICULO
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY R.DATA_COLETA DESC
      ''',
      parameters: params,
    );

    var litros = 0.0;
    final linhas = rows.map((r) {
      final l = (r['LITROS'] as num?)?.toDouble() ?? 0;
      litros += l;
      return [
        r['NOME']?.toString() ?? '',
        _dataHora(r['DATA_COLETA']),
        r['MOTORISTA']?.toString() ?? '',
        r['VEI_PLACA']?.toString() ?? '',
        '${(r['FEITAS'] as num?)?.toInt() ?? 0}/${(r['PARADAS'] as num?)?.toInt() ?? 0}',
        numero(l),
        r['STATUS']?.toString() ?? '',
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Rota', flex: 3),
        ColunaRelatorio('Data', tipo: TipoColuna.data),
        ColunaRelatorio('Motorista', flex: 2),
        ColunaRelatorio('Placa'),
        ColunaRelatorio('Paradas', tipo: TipoColuna.numero),
        ColunaRelatorio('Litros', tipo: TipoColuna.numero),
        ColunaRelatorio('Situação'),
      ],
      linhas: linhas,
      totais: {
        'Rotas': '${rows.length}',
        'Total coletado': '${numero(litros)} L',
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  Future<ResultadoRelatorio> _alertasTemperatura(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'D.DATA_HORA_REGISTRO');
    final where = <String>[
      "D.STATUS = 'CONFIRMADO'",
      'D.TEMPERATURA_LEITE_C > 7',
      if (wPeriodo.isNotEmpty) wPeriodo,
    ];

    final rows = await db.selectAll(
      sql:
          '''
        SELECT D.DATA_HORA_REGISTRO, P.PES_RSOCIAL_NOME, R.NOME AS ROTA,
               D.TEMPERATURA_LEITE_C, D.VOLUME_COLETADO_LITROS
        FROM COLETAS_DETALHE D
        LEFT JOIN TB_PESSOA P ON P.PES_ID = D.ID_PRODUTOR
        LEFT JOIN COLETAS_ROTA R ON R.ID = D.ID_COLETA_ROTA
        WHERE ${where.join(' AND ')}
        ORDER BY D.TEMPERATURA_LEITE_C DESC
      ''',
      parameters: params,
    );

    var litros = 0.0;
    final linhas = rows.map((r) {
      final v = (r['VOLUME_COLETADO_LITROS'] as num?)?.toDouble() ?? 0;
      litros += v;
      return [
        _dataHora(r['DATA_HORA_REGISTRO']),
        r['PES_RSOCIAL_NOME']?.toString() ?? '',
        r['ROTA']?.toString() ?? '',
        numero((r['TEMPERATURA_LEITE_C'] as num?)?.toDouble() ?? 0, casas: 1),
        numero(v),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Data', tipo: TipoColuna.data),
        ColunaRelatorio('Produtor', flex: 3),
        ColunaRelatorio('Rota', flex: 2),
        ColunaRelatorio('Temp. °C', tipo: TipoColuna.numero),
        ColunaRelatorio('Litros', tipo: TipoColuna.numero),
      ],
      linhas: linhas,
      totais: {
        'Ocorrências': '${rows.length}',
        'Volume afetado': '${numero(litros)} L',
        'Limite': '7,0 °C',
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  // ═══════════════════════ FINANCEIRO ═══════════════════════

  Future<ResultadoRelatorio> _movimentacoes(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'M.MOV_DT_EMISSAO');
    final where = <String>[if (wPeriodo.isNotEmpty) wPeriodo];
    if (f.contaId != null) {
      where.add('M.MOV_CONTA = ?');
      params.add(f.contaId);
    }
    if (f.tipoMovimento != null && f.tipoMovimento!.isNotEmpty) {
      where.add('M.MOV_TIPO = ?');
      params.add(f.tipoMovimento);
    }

    final rows = await db.selectAll(
      sql:
          '''
        SELECT M.MOV_DT_EMISSAO, M.MOV_HISTORICO, C.CNT_DESCRICAO,
               M.MOV_TIPO, M.MOV_VALOR
        FROM TB_MOVIMENTO_CONTA M
        LEFT JOIN TB_CONTA C ON C.CNT_ID = M.MOV_CONTA
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY M.MOV_DT_EMISSAO DESC, M.MOV_ID DESC
      ''',
      parameters: params,
    );

    var entradas = 0.0;
    var saidas = 0.0;
    final linhas = rows.map((r) {
      final valor = (r['MOV_VALOR'] as num?)?.toDouble() ?? 0;
      final tipo = r['MOV_TIPO']?.toString() ?? 'C';
      if (tipo == 'C') {
        entradas += valor;
      } else {
        saidas += valor;
      }
      return [
        _dataHora(r['MOV_DT_EMISSAO']),
        r['MOV_HISTORICO']?.toString() ?? '',
        r['CNT_DESCRICAO']?.toString() ?? '',
        tipo == 'C' ? 'Entrada' : 'Saída',
        dinheiro(valor),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Data', tipo: TipoColuna.data),
        ColunaRelatorio('Histórico', flex: 4),
        ColunaRelatorio('Conta', flex: 2),
        ColunaRelatorio('Tipo'),
        ColunaRelatorio('Valor', tipo: TipoColuna.dinheiro),
      ],
      linhas: linhas,
      totais: {
        'Lançamentos': '${rows.length}',
        'Entradas': dinheiro(entradas),
        'Saídas': dinheiro(saidas),
        'Resultado': dinheiro(entradas - saidas),
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  Future<ResultadoRelatorio> _saldosConta() async {
    final db = await _db;
    final rows = await db.selectAll(
      sql: '''
        SELECT C.CNT_DESCRICAO, C.CNT_TIPO,
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

    var total = 0.0;
    final linhas = rows.map((r) {
      final saldo = (r['SALDO'] as num?)?.toDouble() ?? 0;
      total += saldo;
      return [
        r['CNT_DESCRICAO']?.toString() ?? '',
        r['CNT_TIPO']?.toString() == 'B' ? 'Banco' : 'Caixa',
        dinheiro(saldo),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Conta', flex: 4),
        ColunaRelatorio('Tipo'),
        ColunaRelatorio('Saldo', tipo: TipoColuna.dinheiro),
      ],
      linhas: linhas,
      totais: {'Contas': '${rows.length}', 'Saldo total': dinheiro(total)},
      descricaoFiltros: 'Posição em ${data(DateTime.now())}',
    );
  }

  Future<ResultadoRelatorio> _resumoPlanoContas(ValoresFiltro f) async {
    final db = await _db;
    final (wPeriodo, params) = _periodo(f, 'M.MOV_DT_EMISSAO');

    final rows = await db.selectAll(
      sql:
          '''
        SELECT C.CNT_DESCRICAO,
               COALESCE(SUM(CASE WHEN M.MOV_TIPO = 'C' THEN M.MOV_VALOR ELSE 0 END), 0) AS ENTRADAS,
               COALESCE(SUM(CASE WHEN M.MOV_TIPO = 'D' THEN M.MOV_VALOR ELSE 0 END), 0) AS SAIDAS,
               COUNT(M.MOV_ID) AS QTD
        FROM TB_CONTA C
        LEFT JOIN TB_MOVIMENTO_CONTA M ON M.MOV_CONTA = C.CNT_ID
             ${wPeriodo.isEmpty ? '' : 'AND $wPeriodo'}
        WHERE (C.CNT_STATUS IS NULL OR C.CNT_STATUS = 'A')
        GROUP BY C.CNT_ID, C.CNT_DESCRICAO
        ORDER BY C.CNT_DESCRICAO
      ''',
      parameters: params,
    );

    var totalE = 0.0;
    var totalS = 0.0;
    final linhas = rows.map((r) {
      final e = (r['ENTRADAS'] as num?)?.toDouble() ?? 0;
      final s = (r['SAIDAS'] as num?)?.toDouble() ?? 0;
      totalE += e;
      totalS += s;
      return [
        r['CNT_DESCRICAO']?.toString() ?? '',
        '${(r['QTD'] as num?)?.toInt() ?? 0}',
        dinheiro(e),
        dinheiro(s),
        dinheiro(e - s),
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Conta', flex: 4),
        ColunaRelatorio('Lanç.', tipo: TipoColuna.numero),
        ColunaRelatorio('Entradas', tipo: TipoColuna.dinheiro),
        ColunaRelatorio('Saídas', tipo: TipoColuna.dinheiro),
        ColunaRelatorio('Saldo', tipo: TipoColuna.dinheiro),
      ],
      linhas: linhas,
      totais: {
        'Entradas': dinheiro(totalE),
        'Saídas': dinheiro(totalS),
        'Resultado': dinheiro(totalE - totalS),
      },
      descricaoFiltros: _descreverPeriodo(f),
    );
  }

  // ═══════════════════════ CADASTROS ═══════════════════════

  Future<ResultadoRelatorio> _produtores(ValoresFiltro f) async {
    final db = await _db;
    final params = <dynamic>[];
    var where = "P.PES_CLIENTE = 'S'";
    if (f.status != null && f.status!.isNotEmpty) {
      where += ' AND P.PES_STATUS = ?';
      params.add(f.status);
    }

    final rows = await db.selectAll(
      sql:
          '''
        SELECT P.PES_RSOCIAL_NOME, P.PES_CNPJ_CPF, P.PES_CELULAR,
               P.PES_VOLUME_MEDIO, P.PES_HR_COLETA, P.PES_STATUS
        FROM TB_PESSOA P
        WHERE $where
        ORDER BY P.PES_RSOCIAL_NOME
      ''',
      parameters: params,
    );

    var volume = 0.0;
    final linhas = rows.map((r) {
      final v = (r['PES_VOLUME_MEDIO'] as num?)?.toDouble() ?? 0;
      volume += v;
      return [
        r['PES_RSOCIAL_NOME']?.toString() ?? '',
        r['PES_CNPJ_CPF']?.toString() ?? '',
        r['PES_CELULAR']?.toString() ?? '',
        numero(v),
        r['PES_HR_COLETA']?.toString() ?? '',
        r['PES_STATUS']?.toString() == 'A' ? 'Ativo' : 'Inativo',
      ];
    }).toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Produtor', flex: 4),
        ColunaRelatorio('CNPJ/CPF', flex: 2),
        ColunaRelatorio('Celular', flex: 2),
        ColunaRelatorio('Vol. médio', tipo: TipoColuna.numero),
        ColunaRelatorio('Horário'),
        ColunaRelatorio('Situação'),
      ],
      linhas: linhas,
      totais: {
        'Produtores': '${rows.length}',
        'Volume médio diário': '${numero(volume)} L',
      },
      descricaoFiltros: f.status == null
          ? 'Todos'
          : (f.status == 'A' ? 'Somente ativos' : 'Somente inativos'),
    );
  }

  Future<ResultadoRelatorio> _frota(ValoresFiltro f) async {
    final db = await _db;
    final params = <dynamic>[];
    var filtroStatus = '';
    if (f.status != null && f.status!.isNotEmpty) {
      filtroStatus = ' AND STATUS = ?';
    }

    // Motoristas e veículos numa lista só: a frota costuma ser consultada junta.
    final motoristas = await db.selectAll(
      sql:
          '''
        SELECT 'Motorista' AS TIPO, PES_RSOCIAL_NOME AS NOME, PES_CNH AS DOC,
               PES_VALIDADE_CNH AS DETALHE, PES_CELULAR AS CONTATO, PES_STATUS AS STATUS
        FROM TB_PESSOA
        WHERE PES_TRANSPORTADOR = 'S'${filtroStatus.replaceAll('STATUS', 'PES_STATUS')}
        ORDER BY PES_RSOCIAL_NOME
      ''',
      parameters: [...params, if (f.status != null) f.status],
    );

    final veiculos = await db.selectAll(
      sql:
          '''
        SELECT 'Veículo' AS TIPO, VEI_PLACA AS NOME, VEI_RENAVAM AS DOC,
               VEI_MARCA || ' ' || VEI_MODELO AS DETALHE, VEI_ANO_FAB AS CONTATO,
               VEI_STATUS AS STATUS
        FROM TB_VEICULO
        WHERE 1=1${filtroStatus.replaceAll('STATUS', 'VEI_STATUS')}
        ORDER BY VEI_PLACA
      ''',
      parameters: [if (f.status != null) f.status],
    );

    final linhas = [...motoristas, ...veiculos]
        .map(
          (r) => [
            r['TIPO']?.toString() ?? '',
            r['NOME']?.toString() ?? '',
            r['DOC']?.toString() ?? '',
            r['DETALHE']?.toString() ?? '',
            r['CONTATO']?.toString() ?? '',
            r['STATUS']?.toString() == 'A' ? 'Ativo' : 'Inativo',
          ],
        )
        .toList();

    return ResultadoRelatorio(
      colunas: const [
        ColunaRelatorio('Tipo'),
        ColunaRelatorio('Nome / Placa', flex: 3),
        ColunaRelatorio('CNH / Renavam', flex: 2),
        ColunaRelatorio('Detalhe', flex: 3),
        ColunaRelatorio('Contato / Ano'),
        ColunaRelatorio('Situação'),
      ],
      linhas: linhas,
      totais: {
        'Motoristas': '${motoristas.length}',
        'Veículos': '${veiculos.length}',
      },
      descricaoFiltros: f.status == null
          ? 'Todos'
          : (f.status == 'A' ? 'Somente ativos' : 'Somente inativos'),
    );
  }
}
