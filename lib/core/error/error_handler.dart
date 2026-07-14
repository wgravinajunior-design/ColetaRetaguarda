import 'package:flutter/material.dart';
import '../logging/app_logger.dart';
import '../analytics/analytics_service.dart';

/// Tratamento centralizado de erros da aplicação
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();

  factory ErrorHandler() {
    return _instance;
  }

  ErrorHandler._internal();

  final AppLogger _logger = AppLogger();
  final AnalyticsService _analytics = AnalyticsService();
  BuildContext? _context;

  /// Define contexto para exibir snackbars
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Formata mensagens de erro para exibição ao usuário
  String _formatErrorMessage(Object error) {
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('SocketException')) {
        return 'Falha na conexão. Verifique a conexão de rede.';
      }
      if (message.contains('TimeoutException')) {
        return 'Operação expirou. Tente novamente.';
      }
      if (message.contains('ClientException')) {
        return 'Erro na requisição. Verifique os dados.';
      }
      return 'Ocorreu um erro. Tente novamente.';
    }
    return 'Erro desconhecido.';
  }

  /// Loga e exibe erro ao usuário
  void handleError(
    Object error, {
    String? errorCode,
    String? screenName,
    StackTrace? stackTrace,
  }) {
    final errorMsg = _formatErrorMessage(error);
    final code = errorCode ?? 'UNKNOWN';

    _logger.error(
      screenName ?? 'ErrorHandler',
      'Error ($code): $error',
      stackTrace,
    );

    _analytics.trackError(
      code,
      errorMessage: error.toString(),
      screenName: screenName,
    );

    _showSnackBar(errorMsg);
  }

  /// Loga e exibe sucesso ao usuário
  void handleSuccess(String message, {String? screenName}) {
    _logger.info(screenName ?? 'ErrorHandler', message);
    _showSnackBar(message, isSuccess: true);
  }

  /// Exibe snackbar com mensagem
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (_context == null) {
      _logger.warning('ErrorHandler', 'Context not set for snackbar');
      return;
    }

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Exibe diálogo de erro crítico
  Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? buttonLabel,
    VoidCallback? onDismiss,
  }) async {
    _analytics.trackError('DIALOG_ERROR', errorMessage: message);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss?.call();
            },
            child: Text(buttonLabel ?? 'OK'),
          ),
        ],
      ),
    );
  }
}

/// Extension para facilitar uso em widgets
extension ErrorHandlerExtension on BuildContext {
  ErrorHandler get errorHandler => ErrorHandler();

  void handleError(
    Object error, {
    String? errorCode,
    String? screenName,
    StackTrace? stackTrace,
  }) {
    ErrorHandler().setContext(this);
    ErrorHandler().handleError(
      error,
      errorCode: errorCode,
      screenName: screenName,
      stackTrace: stackTrace,
    );
  }

  void handleSuccess(String message, {String? screenName}) {
    ErrorHandler().setContext(this);
    ErrorHandler().handleSuccess(message, screenName: screenName);
  }
}
