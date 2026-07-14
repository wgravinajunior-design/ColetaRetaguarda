/// Estados possíveis durante operações assíncronas
enum AppStateStatus {
  idle,      // Sem operação ativa
  loading,   // Operação em progresso
  success,   // Operação completada com sucesso
  error,     // Operação falhou
  empty,     // Nenhum dado disponível
}

/// Modelo genérico para representar estado de operação
class AppState<T> {
  final AppStateStatus status;
  final T? data;
  final String? error;
  final String? message;

  AppState({
    required this.status,
    this.data,
    this.error,
    this.message,
  });

  /// Estado inicial (idle)
  factory AppState.idle() => AppState(status: AppStateStatus.idle);

  /// Estado de carregamento
  factory AppState.loading({String? message}) =>
      AppState(status: AppStateStatus.loading, message: message);

  /// Estado de sucesso
  factory AppState.success(T data, {String? message}) =>
      AppState(status: AppStateStatus.success, data: data, message: message);

  /// Estado de erro
  factory AppState.error(String error) =>
      AppState(status: AppStateStatus.error, error: error);

  /// Estado de vazio
  factory AppState.empty({String? message}) =>
      AppState(status: AppStateStatus.empty, message: message);

  /// Verifica se está carregando
  bool get isLoading => status == AppStateStatus.loading;

  /// Verifica se é sucesso
  bool get isSuccess => status == AppStateStatus.success;

  /// Verifica se é erro
  bool get isError => status == AppStateStatus.error;

  /// Verifica se é vazio
  bool get isEmpty => status == AppStateStatus.empty;

  /// Verifica se é idle
  bool get isIdle => status == AppStateStatus.idle;

  /// Verifica se tem dados
  bool get hasData => data != null;

  /// Mapeia o estado para outro tipo
  AppState<U> map<U>(U Function(T) fn) {
    if (!hasData) {
      return AppState<U>(
        status: status,
        error: error,
        message: message,
      );
    }
    return AppState<U>(
      status: status,
      data: fn(data as T),
      error: error,
      message: message,
    );
  }

  /// Executa função baseada no estado
  void when({
    required Function() onIdle,
    required Function() onLoading,
    required Function(T data) onSuccess,
    required Function(String error) onError,
    required Function() onEmpty,
  }) {
    switch (status) {
      case AppStateStatus.idle:
        onIdle();
        break;
      case AppStateStatus.loading:
        onLoading();
        break;
      case AppStateStatus.success:
        if (hasData) {
          onSuccess(data as T);
        }
        break;
      case AppStateStatus.error:
        onError(error ?? 'Unknown error');
        break;
      case AppStateStatus.empty:
        onEmpty();
        break;
    }
  }

  @override
  String toString() =>
      'AppState(status: $status, hasData: $hasData, error: $error)';
}
