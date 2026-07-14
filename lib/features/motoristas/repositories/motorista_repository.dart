import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../core/database/daos/motorista_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/motorista_model.dart';

class MotoristaRepository {
  final ApiClient _apiClient = ApiClient();
  final MotoristaDao _dao = MotoristaDao();
  final SyncService _syncService = SyncService();

  Future<List<MotoristaModel>> getMotoristas({String? query}) async {
    try {
      final response = await _apiClient.get(
        '/coleta/motoristas${query != null ? '?q=$query' : ''}',
      );

      if (response.success && response.data is List) {
        final motoristas = (response.data as List)
            .map((e) => MotoristaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (var m in motoristas) {
          await _dao.insert(m);
        }
        return motoristas;
      }
    } catch (e) {
      print('Erro ao buscar motoristas da API: $e');
    }

    try {
      return await _dao.getAll();
    } catch (e) {
      print('Erro ao buscar motoristas do SQLite: $e');
    }

    return getMockMotoristas();
  }

  Future<MotoristaModel?> getMotoristaById(int id) async {
    try {
      final response = await _apiClient.get('/coleta/motoristas/$id');
      if (response.success && response.data != null) {
        final motorista = MotoristaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(motorista);
        return motorista;
      }
    } catch (e) {
      print('Erro ao buscar motorista $id da API: $e');
    }

    try {
      return await _dao.getById(id);
    } catch (e) {
      print('Erro ao buscar motorista $id do SQLite: $e');
    }

    return null;
  }

  Future<MotoristaModel?> createMotorista(MotoristaModel motorista) async {
    try {
      final response = await _apiClient.post(
        '/coleta/motoristas',
        body: motorista.toJson(),
      );

      if (response.success && response.data != null) {
        final created = MotoristaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(created);
        return created;
      }
    } catch (e) {
      print('Erro ao criar motorista na API: $e');
    }

    motorista.id ??= DateTime.now().millisecondsSinceEpoch;
    await _dao.insert(motorista);
    await _syncService.queueOperation(
      tabela: 'tb_motorista',
      operacao: 'CREATE',
      registroId: motorista.id,
      dados: motorista.toJson(),
    );
    return motorista;
  }

  Future<bool> updateMotorista(MotoristaModel motorista) async {
    if (motorista.id == null) return false;

    try {
      final response = await _apiClient.put(
        '/coleta/motoristas/${motorista.id}',
        body: motorista.toJson(),
      );

      if (response.success) {
        await _dao.update(motorista);
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar motorista na API: $e');
    }

    await _dao.update(motorista);
    await _syncService.queueOperation(
      tabela: 'tb_motorista',
      operacao: 'UPDATE',
      registroId: motorista.id,
      dados: motorista.toJson(),
    );
    return true;
  }

  Future<bool> deleteMotorista(int id) async {
    try {
      await _apiClient.delete('/coleta/motoristas/$id');
      await _dao.delete(id);
      return true;
    } catch (e) {
      print('Erro ao deletar motorista na API: $e');
    }

    await _dao.delete(id);
    await _syncService.queueOperation(
      tabela: 'tb_motorista',
      operacao: 'DELETE',
      registroId: id,
      dados: {'id': id},
    );
    return true;
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
