import '../../../core/api/http_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../models/veiculo_model.dart';

class VeiculoRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<VeiculoModel>> getVeiculos({String? query}) async {
    try {
      final params = <String, String>{};
      if (query != null) params['search'] = query;

      final response = await _apiClient.get(
        ApiEndpoints.veiculos,
        queryParams: params.isNotEmpty ? params : null,
      );

      if (response.success && response.data is List) {
        return (response.data as List)
            .map((e) => VeiculoModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return getMockVeiculos();
    } catch (e) {
      return getMockVeiculos();
    }
  }

  Future<VeiculoModel?> getVeiculoById(int id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.veiculos}/$id');
      if (response.success && response.data != null) {
        return VeiculoModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<VeiculoModel?> createVeiculo(VeiculoModel v) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.veiculos,
        body: v.toJson(),
      );
      if (response.success && response.data != null) {
        return VeiculoModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateVeiculo(VeiculoModel v) async {
    if (v.id == null) return false;
    try {
      final response = await _apiClient.put(
        '${ApiEndpoints.veiculos}/${v.id}',
        body: v.toJson(),
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVeiculo(int id) async {
    try {
      final response =
          await _apiClient.delete('${ApiEndpoints.veiculos}/$id');
      return response.success;
    } catch (e) {
      return false;
    }
  }

  List<VeiculoModel> getMockVeiculos() {
    return [
      VeiculoModel(
        id: 1,
        placa: 'ABC-1234',
        marca: 'Mercedes',
        modelo: 'Sprinter',
        cor: 'Branco',
        ano: '2022',
        tipo: 'F',
        renavam: '12345678901234',
        status: 'A',
      ),
      VeiculoModel(
        id: 2,
        placa: 'XYZ-5678',
        marca: 'Volvo',
        modelo: 'FH',
        cor: 'Branco',
        ano: '2021',
        tipo: 'C',
        renavam: '98765432109876',
        status: 'A',
      ),
    ];
  }
}
