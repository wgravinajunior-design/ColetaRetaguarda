import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum de idiomas suportados
enum AppLocale {
  pt('pt-BR', 'Português'),
  en('en-US', 'English'),
  es('es-ES', 'Español');

  final String code;
  final String name;

  const AppLocale(this.code, this.name);
}

/// Gerencia strings da aplicação com suporte a i18n
class AppStrings {
  static final AppStrings _instance = AppStrings._internal();

  factory AppStrings() {
    return _instance;
  }

  AppStrings._internal();

  static const String _localeKey = 'app_locale';

  late AppLocale _currentLocale;
  Function(AppLocale)? _onLocaleChanged;

  final Map<AppLocale, Map<String, String>> _strings = {
    AppLocale.pt: {
      // Common
      'app_name': 'ColetaUp',
      'back': 'Voltar',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'delete': 'Excluir',
      'edit': 'Editar',
      'save': 'Salvar',
      'loading': 'Carregando...',
      'error': 'Erro',
      'success': 'Sucesso',

      // Auth
      'login': 'Entrar',
      'logout': 'Sair',
      'username': 'Usuário',
      'password': 'Senha',
      'login_error': 'Usuário ou senha inválidos',
      'login_blocked': 'Conta bloqueada por 15 minutos',

      // Navigation
      'home': 'Início',
      'produtores': 'Produtores',
      'motoristas': 'Motoristas',
      'coleta': 'Coleta',
      'financeiro': 'Financeiro',
      'settings': 'Configurações',

      // Coleta
      'start_collection': 'Iniciar Coleta',
      'gps_captured': 'GPS Capturado',
      'temperature': 'Temperatura',
      'volume': 'Volume',
      'status_pending': 'Pendente',
      'status_success': 'Sucesso',
      'status_refused': 'Recusada',

      // Settings
      'theme': 'Tema',
      'dark_mode': 'Modo Escuro',
      'language': 'Idioma',
      'database_config': 'Configuração do Banco',
      'version': 'Versão',
    },
    AppLocale.en: {
      // Common
      'app_name': 'ColetaUp',
      'back': 'Back',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'edit': 'Edit',
      'save': 'Save',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',

      // Auth
      'login': 'Sign In',
      'logout': 'Sign Out',
      'username': 'Username',
      'password': 'Password',
      'login_error': 'Invalid username or password',
      'login_blocked': 'Account locked for 15 minutes',

      // Navigation
      'home': 'Home',
      'produtores': 'Producers',
      'motoristas': 'Drivers',
      'coleta': 'Collection',
      'financeiro': 'Finance',
      'settings': 'Settings',

      // Coleta
      'start_collection': 'Start Collection',
      'gps_captured': 'GPS Captured',
      'temperature': 'Temperature',
      'volume': 'Volume',
      'status_pending': 'Pending',
      'status_success': 'Success',
      'status_refused': 'Refused',

      // Settings
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'database_config': 'Database Config',
      'version': 'Version',
    },
    AppLocale.es: {
      // Common
      'app_name': 'ColetaUp',
      'back': 'Atrás',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'save': 'Guardar',
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',

      // Auth
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'username': 'Usuario',
      'password': 'Contraseña',
      'login_error': 'Usuario o contraseña inválidos',
      'login_blocked': 'Cuenta bloqueada por 15 minutos',

      // Navigation
      'home': 'Inicio',
      'produtores': 'Productores',
      'motoristas': 'Conductores',
      'coleta': 'Recolección',
      'financeiro': 'Finanzas',
      'settings': 'Configuración',

      // Coleta
      'start_collection': 'Iniciar Recolección',
      'gps_captured': 'GPS Capturado',
      'temperature': 'Temperatura',
      'volume': 'Volumen',
      'status_pending': 'Pendiente',
      'status_success': 'Éxito',
      'status_refused': 'Rechazado',

      // Settings
      'theme': 'Tema',
      'dark_mode': 'Modo Oscuro',
      'language': 'Idioma',
      'database_config': 'Config. de BD',
      'version': 'Versión',
    },
  };

  /// Inicializa com o idioma padrão
  Future<void> initialize({AppLocale defaultLocale = AppLocale.pt}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode != null) {
        _currentLocale = AppLocale.values.firstWhere(
          (l) => l.code == localeCode,
          orElse: () => defaultLocale,
        );
      } else {
        _currentLocale = defaultLocale;
      }
    } catch (e) {
      _currentLocale = defaultLocale;
    }
  }

  /// Retorna idioma atual
  AppLocale get currentLocale => _currentLocale;

  /// Define callback para mudanças de idioma
  void setOnLocaleChanged(Function(AppLocale) callback) {
    _onLocaleChanged = callback;
  }

  /// Muda idioma
  Future<void> setLocale(AppLocale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.code);
    } catch (e) {
      debugPrint('Erro ao salvar idioma: $e');
    }

    _onLocaleChanged?.call(_currentLocale);
  }

  /// Retorna string por chave
  String get(String key) {
    return _strings[_currentLocale]?[key] ?? key;
  }

  /// Retorna string com interpolação
  String getFormatted(String key, Map<String, dynamic> params) {
    String result = get(key);
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v.toString());
    });
    return result;
  }

  /// Retorna todos os idiomas disponíveis
  List<AppLocale> get availableLocales => AppLocale.values;
}

// Função global para acessar strings
String t(String key) => AppStrings().get(key);
String tf(String key, Map<String, dynamic> params) => AppStrings().getFormatted(key, params);
