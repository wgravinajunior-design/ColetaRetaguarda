import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'dart:isolate';
import 'core/api/http_client.dart';
import 'core/backend/api_server.dart';
import 'features/auth/auth_service.dart';
import 'features/core/database/sync_service.dart';
import 'features/core/sync/sync_handlers.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/main_layout.dart';
import 'features/produtores/viewmodels/produtor_viewmodel.dart';
import 'features/produtores/screens/produtor_list_screen.dart';
import 'features/produtores/screens/produtor_form_screen.dart';
import 'features/motoristas/viewmodels/motorista_viewmodel.dart';
import 'features/motoristas/screens/motorista_list_screen.dart';
import 'features/motoristas/screens/motorista_form_screen.dart';
import 'features/colaboradores/viewmodels/colaborador_viewmodel.dart';
import 'features/colaboradores/screens/colaborador_list_screen.dart';
import 'features/colaboradores/screens/colaborador_form_screen.dart';
import 'features/financeiro/viewmodels/financeiro_viewmodel.dart';
import 'features/financeiro/screens/financeiro_list_screen.dart';
import 'features/financeiro/screens/financeiro_form_screen.dart';
import 'features/veiculos/screens/veiculo_list_screen.dart';
import 'features/veiculos/screens/veiculo_form_screen.dart';
import 'features/rotas/screens/rota_list_screen.dart';
import 'features/rotas/screens/rota_form_screen.dart';
import 'features/produtores/models/pessoa_model.dart';
import 'features/motoristas/models/motorista_model.dart';
import 'features/colaboradores/models/colaborador_model.dart';
import 'features/veiculos/models/veiculo_model.dart';
import 'features/rotas/models/rota_model.dart';
import 'features/veiculos/viewmodels/veiculo_viewmodel.dart';
import 'features/rotas/viewmodels/rota_viewmodel.dart';
import 'features/coleta/viewmodels/coleta_viewmodel.dart';
import 'features/coleta/screens/coleta_list_screen.dart';
import 'features/coleta/screens/pagamentos_screen.dart';
import 'features/resfriadores/viewmodels/resfriador_viewmodel.dart';
import 'features/resfriadores/models/resfriador_model.dart';
import 'features/resfriadores/screens/resfriador_list_screen.dart';
import 'features/resfriadores/screens/resfriador_form_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/core/database/sync_queue_screen.dart';
import 'features/core/config/config_service.dart';
import 'features/core/services/connectivity_service.dart';
import 'features/core/window/window_service.dart';
import 'features/auth/config_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/analytics/analytics_service.dart';
import 'core/widgets/connection_status_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicia servidor HTTP em isolate separado (para mobile sincronizar)
  Isolate.spawn(_startApiServer, null);

  // Abre a janela no modo login (pequena, centralizada) no desktop
  await WindowService.init();

  final configService = ConfigService();
  await configService.loadConfig();

  final authService = AuthService();
  await authService.checkLoginStatus();

  // Registra os handlers de replay da fila (entidade → repository/Firebird)
  // ANTES de iniciar a conectividade, que já dispara o processamento da fila.
  registerSyncHandlers();
  final syncService = SyncService();
  syncService.setupAutoSync();

  // Ao iniciar, o ConnectivityService escoa o que ficou pendente e agenda o
  // retry periódico + o disparo automático quando a rede volta.
  final connectivityService = ConnectivityService();
  await connectivityService.init();

  final apiClient = ApiClient();
  await apiClient.init();

  // Inicializa serviços de tema e localização
  final appStrings = AppStrings();
  await appStrings.initialize();

  final appTheme = AppTheme();
  await appTheme.loadThemePreference();

  final analytics = AnalyticsService();
  analytics.trackEvent('app_started');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider(create: (_) => ProdutorViewModel()),
        ChangeNotifierProvider(create: (_) => MotoristaViewModel()),
        ChangeNotifierProvider(create: (_) => ColaboradorViewModel()),
        ChangeNotifierProvider(create: (_) => VeiculoViewModel()),
        ChangeNotifierProvider(create: (_) => RotaViewModel()),
        ChangeNotifierProvider(create: (_) => FinanceiroViewModel()),
        ChangeNotifierProvider(create: (_) => ColetaViewModel()),
        ChangeNotifierProvider(create: (_) => ResfriadorViewModel()),
      ],
      child: const ColetaRetaguardaApp(),
    ),
  );
}

class ColetaRetaguardaApp extends StatefulWidget {
  const ColetaRetaguardaApp({super.key});

  @override
  State<ColetaRetaguardaApp> createState() => _ColetaRetaguardaAppState();
}

class _ColetaRetaguardaAppState extends State<ColetaRetaguardaApp> {
  late AppTheme _appTheme;

  @override
  void initState() {
    super.initState();
    _appTheme = AppTheme();
    _appTheme.setOnThemeChanged((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: context.read<AuthService>().isAuthenticated ? '/dashboard' : '/login',
      redirect: (context, state) {
        final auth = context.read<AuthService>();
        final isAuth = auth.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';
        final isConfigRoute = state.matchedLocation == '/config';

        if (!isAuth && !isLoginRoute && !isConfigRoute) return '/login';
        if (isAuth && isLoginRoute) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/config',
          builder: (context, state) => const ConfigScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/produtores',
              builder: (context, state) => const ProdutorListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const ProdutorFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => ProdutorFormScreen(produtor: state.extra as PessoaModel)),
              ]
            ),
            GoRoute(
              path: '/motoristas',
              builder: (context, state) => const MotoristaListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const MotoristaFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => MotoristaFormScreen(motorista: state.extra as MotoristaModel?)),
              ]
            ),
            GoRoute(
              path: '/colaboradores',
              builder: (context, state) => const ColaboradorListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const ColaboradorFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => ColaboradorFormScreen(colaborador: state.extra as ColaboradorModel)),
              ]
            ),
            GoRoute(
              path: '/veiculos',
              builder: (context, state) => const VeiculoListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const VeiculoFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => VeiculoFormScreen(veiculo: state.extra as VeiculoModel)),
              ]
            ),
            GoRoute(
              path: '/rotas',
              builder: (context, state) => const RotaListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const RotaFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => RotaFormScreen(rota: state.extra as RotaModel)),
              ]
            ),
            GoRoute(
              path: '/coleta',
              builder: (context, state) => const ColetaListScreen(),
            ),
            GoRoute(
              path: '/pagamentos',
              builder: (context, state) => const PagamentosScreen(),
            ),
            GoRoute(
              path: '/resfriadores',
              builder: (context, state) => const ResfriadorListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const ResfriadorFormScreen()),
                GoRoute(path: 'editar', builder: (context, state) => ResfriadorFormScreen(resfriador: state.extra as ResfriadorModel)),
              ],
            ),
            GoRoute(
              path: '/sync',
              builder: (context, state) => const SyncQueueScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/financeiro',
              builder: (context, state) => const FinanceiroListScreen(),
              routes: [
                GoRoute(path: 'novo', builder: (context, state) => const FinanceiroFormScreen()),
              ]
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Coleta ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: _appTheme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => ConnectionStatusBanner(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Inicia o servidor HTTP em isolate separado
void _startApiServer(_) async {
  try {
    await ApiServer.start(port: 8080);
  } catch (e) {
    debugPrint('Erro ao iniciar API Server: $e');
  }
}
