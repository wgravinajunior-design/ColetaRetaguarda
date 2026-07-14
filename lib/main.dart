import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/auth_service.dart';
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
import 'features/core/config/config_service.dart';
import 'features/auth/config_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final configService = ConfigService();
  await configService.loadConfig();

  final authService = AuthService();
  await authService.checkLoginStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => ProdutorViewModel()),
        ChangeNotifierProvider(create: (_) => MotoristaViewModel()),
        ChangeNotifierProvider(create: (_) => ColaboradorViewModel()),
        ChangeNotifierProvider(create: (_) => VeiculoViewModel()),
        ChangeNotifierProvider(create: (_) => RotaViewModel()),
        ChangeNotifierProvider(create: (_) => FinanceiroViewModel()),
      ],
      child: const ColetaRetaguardaApp(),
    ),
  );
}

class ColetaRetaguardaApp extends StatelessWidget {
  const ColetaRetaguardaApp({super.key});

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
              builder: (context, state) => const Scaffold(body: Center(child: Text('Dashboard'))),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
