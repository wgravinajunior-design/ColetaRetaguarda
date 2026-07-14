import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/colaborador_model.dart';

class ColaboradorRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<ColaboradorModel>> getColaboradores({String? query}) async {
    try {
      final params = <String, String>{};
      if (query != null) params['search'] = query;

      final response = await _apiClient.get(
        ApiEndpoints.pessoas,
        queryParams: params.isNotEmpty ? params : null,
      );

      if (response.success && response.data is List) {
        return (response.data as List)
            .map((e) => ColaboradorModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return getMockColaboradores();
    } catch (e) {
      return getMockColaboradores();
    }
  }

  Future<ColaboradorModel?> getColaboradorById(int id) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.pessoaById(id));
      if (response.success && response.data != null) {
        return ColaboradorModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ColaboradorModel?> createColaborador(ColaboradorModel c) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.pessoas,
        body: c.toJson(),
      );
      if (response.success && response.data != null) {
        return ColaboradorModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateColaborador(ColaboradorModel c) async {
    if (c.id == null) return false;
    try {
      final response = await _apiClient.put(
        ApiEndpoints.pessoaById(c.id!),
        body: c.toJson(),
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteColaborador(int id) async {
    try {
      final response = await _apiClient.delete(ApiEndpoints.pessoaById(id));
      return response.success;
    } catch (e) {
      return false;
    }
  }

  List<ColaboradorModel> getMockColaboradores() {
    return [
      ColaboradorModel(
        id: 1,
        nome: 'Pedro Oliveira',
        cpf: '333.444.555-66',
        funcao: 'Gerente',
        celular: '(31) 99999-1111',
        status: 'A',
      ),
      ColaboradorModel(
        id: 2,
        nome: 'Ana Silva',
        cpf: '444.555.666-77',
        funcao: 'Assistente',
        celular: '(31) 99999-2222',
        status: 'A',
      ),
    ];
  }
}
