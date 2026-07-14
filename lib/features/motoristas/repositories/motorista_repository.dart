import '../../core/database/firebird_service.dart';
import '../models/motorista_model.dart';

class MotoristaRepository {
  final FirebirdService _firebird = FirebirdService();

  Future<List<MotoristaModel>> getMotoristas({String? query, String? status = 'A'}) async {
    final motoristas = await _firebird.getMotoristas(status: status);
    if (query == null || query.isEmpty) return motoristas;
    final q = query.toLowerCase();
    return motoristas
        .where((m) =>
            (m.nome ?? '').toLowerCase().contains(q) ||
            m.cpf.toLowerCase().contains(q))
        .toList();
  }

  Future<MotoristaModel?> createMotorista(MotoristaModel motorista) async {
    return await _firebird.criarMotorista(motorista);
  }

  Future<bool> updateMotorista(MotoristaModel motorista) async {
    if (motorista.id == null) return false;
    return await _firebird.atualizarMotorista(motorista);
  }

  Future<bool> deleteMotorista(int id) async {
    return await _firebird.excluirMotorista(id);
  }

  /// Mock data para testes
  List<MotoristaModel> getMockMotoristas() {
    return [
      MotoristaModel(
        id: 1,
        nome: 'João da Silva',
        apelido: 'João',
        cpf: '111.222.333-44',
        rg: 'MG-1234567',
        telefone: '(31) 3333-4444',
        celular: '(31) 99999-8888',
        email: 'joao@example.com',
        endereco: 'Rua A',
        numero: '100',
        bairro: 'Bairro A',
        cep: '35000-000',
        cnh: '123456789',
        cnhValidade: '2030-12-31',
        status: 'A',
      ),
      MotoristaModel(
        id: 2,
        nome: 'Maria Santos',
        apelido: 'Maria',
        cpf: '222.333.444-55',
        rg: 'MG-2234567',
        telefone: '(31) 3333-5555',
        celular: '(31) 98888-7777',
        email: 'maria@example.com',
        endereco: 'Rua B',
        numero: '200',
        bairro: 'Bairro B',
        cep: '35000-000',
        cnh: '987654321',
        cnhValidade: '2028-06-30',
        status: 'A',
      ),
    ];
  }
}
