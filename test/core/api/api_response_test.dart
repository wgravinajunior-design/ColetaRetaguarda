import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/api/http_client.dart';

void main() {
  group('ApiResponse', () {
    test('creates successful response', () {
      final response = ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {'id': 1, 'nome': 'João'},
        statusCode: 200,
      );

      expect(response.success, true);
      expect(response.statusCode, 200);
      expect(response.data, isNotNull);
      expect(response.data?['nome'], 'João');
    });

    test('creates error response', () {
      final response = ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Não autorizado',
        statusCode: 401,
      );

      expect(response.success, false);
      expect(response.statusCode, 401);
      expect(response.error, 'Não autorizado');
      expect(response.data, isNull);
    });

    test('creates response with null data', () {
      final response = ApiResponse<dynamic>(
        success: true,
        data: null,
        statusCode: 204,
      );

      expect(response.success, true);
      expect(response.statusCode, 204);
      expect(response.data, isNull);
    });

    test('status code 200 indicates success', () {
      final response = ApiResponse<String>(
        success: true,
        data: 'OK',
        statusCode: 200,
      );

      expect(response.statusCode, 200);
      expect(response.success, true);
    });

    test('status code 201 indicates created', () {
      final response = ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {'id': 1},
        statusCode: 201,
      );

      expect(response.statusCode, 201);
    });

    test('status code 400 indicates bad request', () {
      final response = ApiResponse<dynamic>(
        success: false,
        error: 'Requisição inválida',
        statusCode: 400,
      );

      expect(response.statusCode, 400);
      expect(response.success, false);
    });

    test('status code 500 indicates server error', () {
      final response = ApiResponse<dynamic>(
        success: false,
        error: 'Erro interno do servidor',
        statusCode: 500,
      );

      expect(response.statusCode, 500);
    });
  });
}
