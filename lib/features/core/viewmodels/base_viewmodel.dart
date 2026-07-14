import 'package:flutter/foundation.dart';

enum ViewModelState { idle, loading, success, error }

abstract class BaseViewModel<T> extends ChangeNotifier {
  ViewModelState _state = ViewModelState.idle;
  String? _errorMessage;
  List<T> _items = [];

  ViewModelState get state => _state;
  String? get errorMessage => _errorMessage;
  List<T> get items => _items;
  bool get isLoading => _state == ViewModelState.loading;
  bool get isError => _state == ViewModelState.error;

  void _setState(ViewModelState state, {String? error}) {
    _state = state;
    _errorMessage = error;
    notifyListeners();
  }

  void setLoading() => _setState(ViewModelState.loading);
  void setSuccess() => _setState(ViewModelState.success);
  void setIdle() => _setState(ViewModelState.idle);
  void setError(String message) => _setState(ViewModelState.error, error: message);

  void setItems(List<T> items) {
    _items = items;
    _setState(ViewModelState.success);
  }

  void clearError() => _errorMessage = null;
}
