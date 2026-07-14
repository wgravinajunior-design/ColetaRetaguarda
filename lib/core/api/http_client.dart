import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../network/retry_policy.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int statusCode;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    required this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.fromJson(dynamic json, int statusCode) {
    try {
      final map = json is String ? jsonDecode(json) : json;
      return ApiResponse(
        success: map['success'] ?? false,
        data: map['data'],
        error: map['error'],
        statusCode: statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Erro ao parsear resposta: $e',
        statusCode: statusCode,
      );
    }
  }

  factory ApiResponse.error(String message, {int statusCode = 0}) {
    return ApiResponse(
      success: false,
      error: message,
      statusCode: statusCode,
    );
  }

  @override
  String toString() =>
      'ApiResponse(success: $success, statusCode: $statusCode, error: $error)';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  late String _baseUrl;
  late String _bearerToken;
  final Duration _timeout = const Duration(seconds: 30);
  final int _maxRetries = 3;
  final RetryHelper _retryHelper = RetryHelper();
  final RetryPolicy _retryPolicy = const RetryPolicy(maxAttempts: 3);
  Function(String)? _onLog;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    // Padrão: localhost em desenvolvimento
    // Será sobrescrito por ConfigService em produção
    _baseUrl = 'http://localhost:3000';
    _bearerToken = '';
  }

  /// Força HTTPS em produção
  /// Valida que a URL não use HTTP em release builds
  void validateAndSetBaseUrl(String url) {
    if (url.isEmpty) {
      throw ArgumentError('Base URL não pode estar vazia');
    }

    // Em release, exigir HTTPS (exceto localhost)
    if (!url.contains('localhost') && !url.contains('127.0.0.1')) {
      if (url.startsWith('http://')) {
        throw ArgumentError('HTTPS obrigatório em produção: $url');
      }
      if (!url.startsWith('https://')) {
        throw ArgumentError('URL inválida (deve começar com https://): $url');
      }
    }

    _baseUrl = url;
    _log('Base URL validada: $_baseUrl');
  }

  Future<void> init() async {
    await _loadToken();
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _log('Base URL set to: $_baseUrl');
  }

  void setBearerToken(String token) {
    _bearerToken = token;
    _log('Bearer token updated');
  }

  void setOnLog(Function(String) callback) {
    _onLog = callback;
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bearerToken = prefs.getString('auth_token') ?? '';
    } catch (e) {
      _log('Erro ao carregar token: $e');
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    final logMsg = '[$timestamp] $message';
    _onLog?.call(logMsg);
    debugPrint(logMsg);
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_bearerToken';
    }
    return headers;
  }

  String get baseUrl => _baseUrl;

  /// Testa se o servidor/base está acessível.
  /// Qualquer resposta HTTP (mesmo 404) indica que o servidor respondeu.
  /// Retorna false em caso de erro de socket (conexão recusada) ou timeout.
  Future<bool> checkConnection({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final url = Uri.parse(_baseUrl);
      _log('>>> HEALTHCHECK $url');
      final response = await http.get(url, headers: _getHeaders()).timeout(timeout);
      _log('<<< healthcheck ${response.statusCode}');
      return response.statusCode > 0;
    } catch (e) {
      _log('!!! healthcheck falhou: $e');
      return false;
    }
  }

  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    int retries = 0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: queryParams?.isNotEmpty ?? false ? queryParams : null,
      );

      _log('>>> GET $url');

      final response = await http
          .get(url, headers: _getHeaders())
          .timeout(_timeout);

      _log('<<< ${response.statusCode}');
      if (response.body.isNotEmpty) {
        _log('Response: ${response.body.substring(0, 200)}');
      }

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(response.body, response.statusCode);
      } else if (response.statusCode == 401 && retries < _maxRetries) {
        _log('Retrying after 401... (attempt ${retries + 1}/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 1));
        return get(endpoint, queryParams: queryParams, retries: retries + 1);
      } else {
        return ApiResponse.error(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      _log('!!! TIMEOUT');
      return ApiResponse.error('Timeout na requisição');
    } catch (e) {
      _log('!!! ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> post(
    String endpoint, {
    required Map<String, dynamic> body,
    int retries = 0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final bodyJson = jsonEncode(body);

      _log('>>> POST $url');
      _log('Body: $bodyJson');

      final response = await http
          .post(url, headers: _getHeaders(), body: bodyJson)
          .timeout(_timeout);

      _log('<<< ${response.statusCode}');
      if (response.body.isNotEmpty) {
        _log('Response: ${response.body.substring(0, 200)}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.fromJson(response.body, response.statusCode);
      } else if (response.statusCode == 401 && retries < _maxRetries) {
        _log('Retrying after 401... (attempt ${retries + 1}/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 1));
        return post(endpoint, body: body, retries: retries + 1);
      } else {
        return ApiResponse.error(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      _log('!!! TIMEOUT');
      return ApiResponse.error('Timeout na requisição');
    } catch (e) {
      _log('!!! ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> put(
    String endpoint, {
    required Map<String, dynamic> body,
    int retries = 0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');
      final bodyJson = jsonEncode(body);

      _log('>>> PUT $url');
      _log('Body: $bodyJson');

      final response = await http
          .put(url, headers: _getHeaders(), body: bodyJson)
          .timeout(_timeout);

      _log('<<< ${response.statusCode}');
      if (response.body.isNotEmpty) {
        _log('Response: ${response.body.substring(0, 200)}');
      }

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(response.body, response.statusCode);
      } else if (response.statusCode == 401 && retries < _maxRetries) {
        _log('Retrying after 401... (attempt ${retries + 1}/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 1));
        return put(endpoint, body: body, retries: retries + 1);
      } else {
        return ApiResponse.error(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      _log('!!! TIMEOUT');
      return ApiResponse.error('Timeout na requisição');
    } catch (e) {
      _log('!!! ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse> delete(
    String endpoint, {
    int retries = 0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$endpoint');

      _log('>>> DELETE $url');

      final response = await http
          .delete(url, headers: _getHeaders())
          .timeout(_timeout);

      _log('<<< ${response.statusCode}');
      if (response.body.isNotEmpty) {
        _log('Response: ${response.body.substring(0, 200)}');
      }

      if (response.statusCode == 200) {
        return ApiResponse.fromJson(response.body, response.statusCode);
      } else if (response.statusCode == 401 && retries < _maxRetries) {
        _log('Retrying after 401... (attempt ${retries + 1}/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 1));
        return delete(endpoint, retries: retries + 1);
      } else {
        return ApiResponse.error(
          'HTTP ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      _log('!!! TIMEOUT');
      return ApiResponse.error('Timeout na requisição');
    } catch (e) {
      _log('!!! ERROR: $e');
      return ApiResponse.error(e.toString());
    }
  }
}
