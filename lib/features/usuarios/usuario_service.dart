import '../core/database/db_connection.dart';

/// Um usuário do sistema, como consta em TB_USUARIO.
class UsuarioModel {
  final int? id;
  String nome;
  String login;
  String senha;

  /// Coluna USU_ADMINISTRADOR do ERP ('S'/'N').
  ///
  /// É o único sinal confiável de administrador nesta base: USU_PERFIL é um
  /// INTEGER — o código do grupo de permissões do ERP —, e não um rótulo.
  bool administrador;

  /// 'A' ativo, 'I' inativo.
  String status;

  /// PES_ID do motorista vinculado (USU_MOTORISTA_ID), ou null.
  ///
  /// É o que faz o app do celular mostrar a este usuário apenas as rotas do
  /// motorista dele, em vez das de todo mundo.
  int? motoristaId;

  UsuarioModel({
    this.id,
    this.nome = '',
    this.login = '',
    this.senha = '',
    this.administrador = false,
    this.status = 'A',
    this.motoristaId,
  });

  bool get ativo => status.toUpperCase() != 'I';
}

/// Leitura e escrita dos usuários na TB_USUARIO da base do ERP.
///
/// A tabela é do ERP e traz dezenas de colunas de permissão que não dizem
/// respeito à coleta. Aqui só se mexe no punhado que o login usa; o resto fica
/// como o ERP deixou.
class UsuarioService {
  static final UsuarioService _instance = UsuarioService._internal();
  factory UsuarioService() => _instance;
  UsuarioService._internal();

  Future<dynamic> get _db async => DbConnection().db;

  static String _texto(dynamic v) => v == null ? '' : '$v'.trim();

  bool? _temColunaMotorista;

  /// Se a TB_USUARIO já tem a coluna do vínculo com o motorista.
  ///
  /// A coluna é acrescentada pela coleta à tabela do ERP, na atualização de
  /// schema que roda ao abrir o sistema. Numa base onde ela ainda não passou —
  /// o banco pode estar fora do ar naquele momento — pedir a coluna no SELECT
  /// derrubaria a tela de usuários inteira. Descobre uma vez e guarda.
  Future<bool> _colunaMotoristaExiste() async {
    final cache = _temColunaMotorista;
    if (cache != null) return cache;
    final db = await _db;
    final row = await db.selectOne(
      sql: r'''SELECT COUNT(*) AS N FROM RDB$RELATION_FIELDS
               WHERE RDB$RELATION_NAME = 'TB_USUARIO'
                 AND TRIM(RDB$FIELD_NAME) = 'USU_MOTORISTA_ID' ''',
    );
    final existe = ((row?['N'] as int?) ?? 0) > 0;
    _temColunaMotorista = existe;
    return existe;
  }

  Future<List<UsuarioModel>> listar() async {
    final db = await _db;
    final comMotorista = await _colunaMotoristaExiste();
    final colunaMotorista = comMotorista ? ', USU_MOTORISTA_ID' : '';
    final rows = await db.selectAll(
      sql:
          'SELECT USU_ID, USU_NOME, USU_LOGIN, USU_SENHA, '
          'USU_ADMINISTRADOR, USU_STATUS$colunaMotorista '
          'FROM TB_USUARIO ORDER BY USU_NOME',
    );
    return rows
        .map<UsuarioModel>(
          (r) => UsuarioModel(
            id: r['USU_ID'] as int?,
            nome: _texto(r['USU_NOME']),
            login: _texto(r['USU_LOGIN']),
            senha: _texto(r['USU_SENHA']),
            administrador: _texto(r['USU_ADMINISTRADOR']).toUpperCase() == 'S',
            // Cadastro antigo do ERP costuma vir com o status em branco. Tratar
            // isso como inativo trancaria o usuário para fora sem explicação.
            status: _texto(r['USU_STATUS']).isEmpty
                ? 'A'
                : _texto(r['USU_STATUS']).toUpperCase(),
            motoristaId: comMotorista ? r['USU_MOTORISTA_ID'] as int? : null,
          ),
        )
        .toList();
  }

  /// Verdadeiro se já existe outro usuário com este login.
  Future<bool> loginEmUso(String login, {int? ignorandoId}) async {
    final alvo = login.trim().toUpperCase();
    if (alvo.isEmpty) return false;
    final todos = await listar();
    return todos.any(
      (u) => u.login.toUpperCase() == alvo && u.id != ignorandoId,
    );
  }

  Future<int> _proximoId() async {
    final db = await _db;
    final row = await db.selectOne(
      sql: 'SELECT COALESCE(MAX(USU_ID),0)+1 AS NID FROM TB_USUARIO',
    );
    return (row?['NID'] as int?) ?? 1;
  }

  Future<int> criar(UsuarioModel u) async {
    final db = await _db;
    final id = await _proximoId();
    final comMotorista = await _colunaMotoristaExiste();
    await db.execute(
      sql:
          // USU_PERFIL fica de fora de propósito: é o código do grupo de
          // permissões do ERP, e inventar um valor aqui mexeria no que o
          // usuário pode fazer lá dentro.
          'INSERT INTO TB_USUARIO '
          '(USU_ID, USU_NOME, USU_LOGIN, USU_SENHA, '
          ' USU_ADMINISTRADOR, USU_STATUS'
          '${comMotorista ? ', USU_MOTORISTA_ID' : ''}) '
          'VALUES (?, ?, ?, ?, ?, ?${comMotorista ? ', ?' : ''})',
      parameters: [
        id,
        u.nome,
        u.login,
        u.senha,
        u.administrador ? 'S' : 'N',
        u.ativo ? 'A' : 'I',
        if (comMotorista) u.motoristaId,
      ],
    );
    return id;
  }

  Future<void> atualizar(UsuarioModel u) async {
    if (u.id == null) return;
    final db = await _db;
    final comMotorista = await _colunaMotoristaExiste();

    final campos = <String>['USU_NOME = ?', 'USU_LOGIN = ?'];
    final valores = <dynamic>[u.nome, u.login];

    // A senha em branco significa "não mexer": assim dá para corrigir o nome
    // de alguém sem precisar saber (nem redefinir) a senha dele.
    if (u.senha.isNotEmpty) {
      campos.add('USU_SENHA = ?');
      valores.add(u.senha);
    }

    campos.addAll(['USU_ADMINISTRADOR = ?', 'USU_STATUS = ?']);
    valores.addAll([u.administrador ? 'S' : 'N', u.ativo ? 'A' : 'I']);

    if (comMotorista) {
      campos.add('USU_MOTORISTA_ID = ?');
      valores.add(u.motoristaId);
    }

    valores.add(u.id);
    await db.execute(
      sql: 'UPDATE TB_USUARIO SET ${campos.join(', ')} WHERE USU_ID = ?',
      parameters: valores,
    );
  }

  /// Desativa em vez de apagar: a TB_USUARIO do ERP é referenciada por
  /// lançamentos antigos, e remover a linha deixaria esses registros órfãos.
  Future<void> desativar(int id) async {
    final db = await _db;
    await db.execute(
      sql: "UPDATE TB_USUARIO SET USU_STATUS = 'I' WHERE USU_ID = ?",
      parameters: [id],
    );
  }
}
