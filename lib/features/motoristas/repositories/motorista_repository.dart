import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/motorista_model.dart';

class MotoristaRepository {
  final ApiClient _apiClient = ApiClient();

  /// Busca todos os motoristas
  Future<List<MotoristaModel>> getMotoristas({String? query}) async {
    try {
      final params = <String, String>{};
      if (query != null && query.isNotEmpty) {
        params['search'] = query;
      }

      final response = await _apiClient.get(
        ApiEndpoints.pessoas,
        queryParams: params.isNotEmpty ? params : null,
      );

      if (response.success && response.data is List) {
        return (response.data as List)
            .map((e) => MotoristaModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return getMockMotoristas();
    } catch (e) {
      print('Erro ao buscar motoristas: $e');
      return getMockMotoristas();
    }
  }

  /// Busca motorista por ID
  Future<MotoristaModel?> getMotoristaById(int id) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.pessoaById(id));

      if (response.success && response.data != null) {
        return MotoristaModel.fromJson(response.data as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Erro ao buscar motorista $id: $e');
      return null;
    }
  }

  /// Cria novo motorista
  Future<MotoristaModel?> createMotorista(MotoristaModel motorista) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.pessoas,
        body: motorista.toJson(),
      );

      if (response.success && response.data != null) {
        return MotoristaModel.fromJson(response.data as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Erro ao criar motorista: $e');
      return null;
    }
  }

  /// Atualiza motorista existente
  Future<bool> updateMotorista(MotoristaModel motorista) async {
    if (motorista.id == null) return false;

    try {
      final response = await _apiClient.put(
        ApiEndpoints.pessoaById(motorista.id!),
        body: motorista.toJson(),
      );

      return response.success;
    } catch (e) {
      print('Erro ao atualizar motorista: $e');
      return false;
    }
  }

  /// Deleta motorista
  Future<bool> deleteMotorista(int id) async {
    try {
      final response = await _apiClient.delete(ApiEndpoints.pessoaById(id));
      return response.success;
    } catch (e) {
      print('Erro ao deletar motorista: $e');
      return false;
    }
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
