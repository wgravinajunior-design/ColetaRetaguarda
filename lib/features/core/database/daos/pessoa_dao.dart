import 'package:sqflite/sqflite.dart';
import '../base_dao.dart';
import '../../../produtores/models/pessoa_model.dart';

class PessoaDao extends BaseDao<PessoaModel> {
  @override
  String get tableName => 'tb_pessoa';

  @override
  PessoaModel fromMap(Map<String, dynamic> map) {
    return PessoaModel(
      id: map['id'] as int?,
      tipoPessoa: (map['tipo_pessoa'] as String?) ?? '',
      rSocialNome: (map['rsocial_nome'] as String?) ?? '',
      fantasiaApelido: map['fantasia_apelido'] as String? ?? '',
      cnpjCpf: (map['cnpj_cpf'] as String?) ?? '',
      ieRg: map['ie_rg'] as String? ?? '',
      endereco: map['endereco'] as String? ?? '',
      numero: map['numero'] as String? ?? '',
      complemento: map['complemento'] as String? ?? '',
      bairro: map['bairro'] as String? ?? '',
      cep: map['cep'] as String? ?? '',
      telefone: map['telefone'] as String? ?? '',
      celular: map['celular'] as String? ?? '',
      email: map['email'] as String? ?? '',
      contato: map['contato'] as String? ?? '',
      referencia: map['referencia'] as String? ?? '',
      status: (map['status'] as String?) ?? 'A',
      cliente: (map['cliente'] as String?) ?? 'N',
      transportador: (map['transportador'] as String?) ?? 'N',
      contribuinte: (map['contribuinte'] as String?) ?? 'N',
    );
  }

  @override
  Map<String, dynamic> toMap(PessoaModel obj) {
    return {
      'id': obj.id,
      'tipo_pessoa': obj.tipoPessoa,
      'rsocial_nome': obj.rSocialNome,
      'fantasia_apelido': obj.fantasiaApelido,
      'cnpj_cpf': obj.cnpjCpf,
      'ie_rg': obj.ieRg,
      'endereco': obj.endereco,
      'numero': obj.numero,
      'complemento': obj.complemento,
      'bairro': obj.bairro,
      'cep': obj.cep,
      'telefone': obj.telefone,
      'celular': obj.celular,
      'email': obj.email,
      'contato': obj.contato,
      'referencia': obj.referencia,
      'status': obj.status,
      'cliente': obj.cliente,
      'transportador': obj.transportador,
      'contribuinte': obj.contribuinte,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }

  Future<List<PessoaModel>> getProdutores() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'tipo_pessoa = ?',
      whereArgs: ['P'],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<PessoaModel>> getMotoristas() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'transportador = ?',
      whereArgs: ['S'],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<PessoaModel>> getColaboradores() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'tipo_pessoa = ?',
      whereArgs: ['C'],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<PessoaModel?> getByCnpjCpf(String cnpjCpf) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'cnpj_cpf = ?',
      whereArgs: [cnpjCpf],
    );
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }
}
