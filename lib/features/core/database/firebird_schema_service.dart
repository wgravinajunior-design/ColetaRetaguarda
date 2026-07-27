import 'package:flutter/foundation.dart';
import 'db_connection.dart';

/// Uma coluna que o sistema precisa encontrar na base.
class ColunaEsperada {
  final String nome;

  /// Tipo em SQL do Firebird, usado tanto no CREATE quanto no ALTER.
  final String tipo;

  const ColunaEsperada(this.nome, this.tipo);
}

/// Uma tabela própria do sistema, que precisa existir na base do cliente.
class TabelaEsperada {
  final String nome;
  final List<ColunaEsperada> colunas;

  /// Coluna de chave primária. O sistema gera o valor com `MAX(ID)+1`, então
  /// não há generator nem trigger para criar.
  final String chave;

  /// Quando verdadeiro, a tabela é do ERP e o sistema apenas acrescenta as
  /// colunas que faltam — nunca cria a tabela nem mexe no que já existe.
  final bool doErp;

  const TabelaEsperada({
    required this.nome,
    required this.colunas,
    this.chave = 'ID',
    this.doErp = false,
  });
}

/// Situação de uma tabela na base conferida.
class SituacaoTabela {
  final String tabela;
  final bool existe;
  final List<String> colunasFaltando;

  /// Tabela do ERP: o sistema só acrescenta colunas, nunca a cria.
  final bool doErp;

  const SituacaoTabela({
    required this.tabela,
    required this.existe,
    this.colunasFaltando = const [],
    this.doErp = false,
  });

  bool get ok => existe && colunasFaltando.isEmpty;
}

/// Resultado da conferência da base inteira.
class DiagnosticoSchema {
  final List<SituacaoTabela> tabelas;

  /// Tabelas do ERP das quais o sistema depende, mas que ele não cria.
  final List<String> dependenciasFaltando;

  const DiagnosticoSchema({
    required this.tabelas,
    this.dependenciasFaltando = const [],
  });

  bool get tudoCerto =>
      tabelas.every((t) => t.ok) && dependenciasFaltando.isEmpty;

  int get pendencias =>
      tabelas.where((t) => !t.ok).length + dependenciasFaltando.length;
}

/// Cria e mantém as tabelas do sistema na base Firebird escolhida nas
/// Configurações.
///
/// O sistema roda sobre a base do ERP do cliente, que já traz TB_PESSOA,
/// TB_VEICULO, TB_USUARIO e companhia. Mas as tabelas da coleta são só dele —
/// numa base nova elas não existem, e sem isto era preciso criá-las na mão para
/// cada instalação.
class FirebirdSchemaService {
  static final FirebirdSchemaService _instance =
      FirebirdSchemaService._internal();
  factory FirebirdSchemaService() => _instance;
  FirebirdSchemaService._internal();

  /// Tabelas que o sistema cria e mantém.
  static const tabelas = <TabelaEsperada>[
    TabelaEsperada(
      nome: 'COLETAS_ROTA',
      colunas: [
        ColunaEsperada('ID', 'INTEGER NOT NULL'),
        ColunaEsperada('NOME', 'VARCHAR(80)'),
        ColunaEsperada('ID_MOTORISTA', 'INTEGER'),
        ColunaEsperada('ID_VEICULO', 'INTEGER'),
        ColunaEsperada('DATA_COLETA', 'DATE'),
        ColunaEsperada('DATA_HORA_INICIO', 'TIMESTAMP'),
        ColunaEsperada('DATA_HORA_FIM', 'TIMESTAMP'),
        ColunaEsperada('STATUS', 'VARCHAR(20)'),
      ],
    ),
    TabelaEsperada(
      nome: 'COLETAS_DETALHE',
      colunas: [
        ColunaEsperada('ID', 'INTEGER NOT NULL'),
        ColunaEsperada('ID_COLETA_ROTA', 'INTEGER'),
        ColunaEsperada('ID_PRODUTOR', 'INTEGER'),
        ColunaEsperada('ORDEM_VISITA', 'INTEGER'),
        ColunaEsperada('DATA_HORA_REGISTRO', 'TIMESTAMP'),
        ColunaEsperada('VOLUME_COLETADO_LITROS', 'NUMERIC(15,2)'),
        ColunaEsperada('TEMPERATURA_LEITE_C', 'NUMERIC(15,2)'),
        ColunaEsperada('OBSERVACAO', 'VARCHAR(500)'),
        ColunaEsperada('MOTIVO_ADIAMENTO', 'VARCHAR(500)'),
        ColunaEsperada('STATUS', 'VARCHAR(20)'),
        ColunaEsperada('FOTO_CAMINHO', 'VARCHAR(500)'),
        ColunaEsperada('ASSINATURA_BASE64', 'BLOB SUB_TYPE TEXT'),
        ColunaEsperada('GPS_CAPTURA_LAT', 'DOUBLE PRECISION'),
        ColunaEsperada('GPS_CAPTURA_LON', 'DOUBLE PRECISION'),
        ColunaEsperada('HORARIO_CHEGADA', 'TIMESTAMP'),
      ],
    ),

    // Resfriadores são cadastro da coleta, não do ERP: numa base nova a tabela
    // não existe e a tela de Resfriadores falha inteira sem ela.
    TabelaEsperada(
      nome: 'TB_RESFRIADOR',
      chave: 'RES_ID',
      colunas: [
        ColunaEsperada('RES_ID', 'INTEGER NOT NULL'),
        ColunaEsperada('RES_NUMERO_ID', 'VARCHAR(40)'),
        ColunaEsperada('RES_MARCA_MODELO', 'VARCHAR(120)'),
        ColunaEsperada('RES_ANO_FABRICACAO', 'INTEGER'),
        ColunaEsperada('RES_CAPACIDADE_LITROS', 'NUMERIC(15,2)'),
        ColunaEsperada('RES_ULTIMA_MANUTENCAO', 'DATE'),
        ColunaEsperada('RES_STATUS', 'VARCHAR(20)'),
      ],
    ),

    // TB_PESSOA vem do ERP. O sistema só acrescenta o que a coleta precisa e
    // que o ERP não tem: dados de CNH, localização e parâmetros de coleta.
    // Sem elas, as telas de Produtores e Motoristas não carregam.
    TabelaEsperada(
      nome: 'TB_PESSOA',
      doErp: true,
      colunas: [
        ColunaEsperada('PES_CNH', 'VARCHAR(20)'),
        ColunaEsperada('PES_CATEGORIA_CNH', 'VARCHAR(5)'),
        ColunaEsperada('PES_VALIDADE_CNH', 'VARCHAR(10)'),
        ColunaEsperada('PES_LATITUDE', 'DOUBLE PRECISION'),
        ColunaEsperada('PES_LONGITUDE', 'DOUBLE PRECISION'),
        ColunaEsperada('PES_HR_COLETA', 'VARCHAR(5)'),
        ColunaEsperada('PES_KM', 'NUMERIC(15,2)'),
        ColunaEsperada('PES_VOLUME_MEDIO', 'NUMERIC(15,2)'),
        ColunaEsperada('PES_ID_RESFRIADOR', 'INTEGER'),
      ],
    ),
  ];

  /// Tabelas do ERP que o sistema consulta mas nunca cria — se faltarem, a base
  /// escolhida não é uma base do ERP e avisar é mais útil do que falhar depois.
  static const dependenciasErp = <String>[
    'TB_USUARIO',
    'TB_PESSOA',
    'TB_VEICULO',
    'TB_CONTA',
    'TB_MOVIMENTO_CONTA',
  ];

  Future<Set<String>> _tabelasExistentes() async {
    final db = await DbConnection().db;
    final rows = await db.selectAll(
      sql:
          r"SELECT TRIM(RDB$RELATION_NAME) AS N FROM RDB$RELATIONS "
          r'WHERE RDB$SYSTEM_FLAG = 0',
    );
    return rows.map((r) => (r['N'] ?? '').toString().toUpperCase()).toSet();
  }

  Future<Set<String>> _colunasDe(String tabela) async {
    final db = await DbConnection().db;
    final rows = await db.selectAll(
      sql:
          r'SELECT TRIM(RDB$FIELD_NAME) AS N FROM RDB$RELATION_FIELDS '
          r'WHERE RDB$RELATION_NAME = ?',
      parameters: [tabela.toUpperCase()],
    );
    return rows.map((r) => (r['N'] ?? '').toString().toUpperCase()).toSet();
  }

  /// Confere a base sem alterar nada.
  Future<DiagnosticoSchema> conferir() async {
    final existentes = await _tabelasExistentes();

    final situacoes = <SituacaoTabela>[];
    for (final t in tabelas) {
      if (!existentes.contains(t.nome)) {
        situacoes.add(
          SituacaoTabela(tabela: t.nome, existe: false, doErp: t.doErp),
        );
        continue;
      }
      final colunas = await _colunasDe(t.nome);
      final faltando = t.colunas
          .map((c) => c.nome)
          .where((c) => !colunas.contains(c))
          .toList();
      situacoes.add(
        SituacaoTabela(tabela: t.nome, existe: true, colunasFaltando: faltando),
      );
    }

    final faltandoErp = dependenciasErp
        .where((t) => !existentes.contains(t))
        .toList();

    return DiagnosticoSchema(
      tabelas: situacoes,
      dependenciasFaltando: faltandoErp,
    );
  }

  /// Cria o que falta. Estritamente aditivo: nunca apaga tabela nem coluna,
  /// então rodar numa base que já está em dia não muda nada.
  ///
  /// Devolve a lista do que foi feito, para mostrar ao usuário.
  Future<List<String>> aplicar() async {
    final db = await DbConnection().db;
    final feito = <String>[];
    final existentes = await _tabelasExistentes();

    for (final t in tabelas) {
      if (!existentes.contains(t.nome)) {
        // Tabela do ERP ausente não é caso de criar: significa que a base
        // escolhida não é a do ERP, e inventá-la esconderia o problema real.
        if (t.doErp) {
          feito.add('FALHOU: ${t.nome} não existe — esta base não é do ERP');
          continue;
        }
        final defs = t.colunas.map((c) => '${c.nome} ${c.tipo}').join(', ');
        await db.execute(
          sql:
              'CREATE TABLE ${t.nome} ($defs, '
              'CONSTRAINT PK_${t.nome} PRIMARY KEY (${t.chave}))',
        );
        feito.add('Tabela ${t.nome} criada');
        continue;
      }

      final colunas = await _colunasDe(t.nome);
      for (final c in t.colunas) {
        if (colunas.contains(c.nome)) continue;
        // NOT NULL não se aplica a coluna adicionada em tabela com dados: o
        // Firebird recusa se já houver linhas.
        final tipo = c.tipo.replaceAll(' NOT NULL', '');
        try {
          await db.execute(sql: 'ALTER TABLE ${t.nome} ADD ${c.nome} $tipo');
          feito.add('Coluna ${t.nome}.${c.nome} adicionada');
        } catch (e) {
          debugPrint('Falha ao adicionar ${t.nome}.${c.nome}: $e');
          feito.add('FALHOU: ${t.nome}.${c.nome} — $e');
        }
      }
    }

    if (feito.isEmpty) feito.add('Nada a fazer: a base já está em dia.');
    return feito;
  }
}
