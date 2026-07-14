import '../base_dao.dart';
import '../../motoristas/models/motorista_model.dart';

class MotoristaDao extends BaseDao<MotoristaModel> {
  @override
  String get tableName => 'tb_motorista';

  @override
  MotoristaModel fromMap(Map<String, dynamic> map) {
    return MotoristaModel(
      id: map['id'] as int?,
      nome: map['nome'] as String?,
      apelido: map['apelido'] as String?,
      cpf: map['cpf'] as String? ?? '',
      rg: map['rg'] as String? ?? '',
      telefone: map['telefone'] as String?,
      celular: map['celular'] as String?,
      email: map['email'] as String?,
      endereco: map['endereco'] as String?,
      numero: map['numero'] as String?,
      complemento: map['complemento'] as String?,
      bairro: map['bairro'] as String?,
      cidade: map['cidade'] as String?,
      cep: map['cep'] as String?,
      cnh: map['cnh'] as String?,
      cnhValidade: map['cnh_validade'] as String?,
      status: map['status'] as String? ?? 'A',
    );
  }

  @override
  Map<String, dynamic> toMap(MotoristaModel obj) {
    return {
      'id': obj.id,
      'nome': obj.nome,
      'apelido': obj.apelido,
      'cpf': obj.cpf,
      'rg': obj.rg,
      'telefone': obj.telefone,
      'celular': obj.celular,
      'email': obj.email,
      'endereco': obj.endereco,
      'numero': obj.numero,
      'complemento': obj.complemento,
      'bairro': obj.bairro,
      'cidade': obj.cidade,
      'cep': obj.cep,
      'cnh': obj.cnh,
      'cnh_validade': obj.cnhValidade,
      'status': obj.status,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }
}
