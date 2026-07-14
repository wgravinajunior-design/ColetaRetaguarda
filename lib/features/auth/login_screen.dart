import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import '../core/config/config_service.dart';
import '../core/database/database_inspector_screen.dart';
import '../core/database/db_connection.dart';
import '../core/window/window_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1) Não permite login se a base de dados (Firebird) configurada não conectar
    final conectado = await DbConnection().testarConexao();
    if (!conectado) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Sem conexão com a base de dados configurada.\n'
            'Verifique host, porta e caminho da base nas Configurações.';
      });
      return;
    }

    // 2) Valida credenciais na própria base
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final loginError = await authService.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (loginError == null) {
      // Login bem-sucedido
      // Sistema entra em tela cheia após autenticar
      await WindowService.modoApp();
      if (mounted) context.go('/dashboard');
    } else {
      setState(() {
        _errorMessage = loginError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuta as alterações no ConfigService para atualizar a logo automaticamente após salvar
    final config = context.watch<ConfigService>();
    final logoPath = config.logoPath;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (logoPath.isNotEmpty && File(logoPath).existsSync())
                              Image.file(File(logoPath), height: 100, fit: BoxFit.contain)
                            else
                              const Icon(Icons.business_center, size: 64, color: Colors.blue),
                            const SizedBox(height: 16),
                            Text(
                              'ColetaUp',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'v1.17.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.red.shade100,
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Usuário',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Senha',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text('ENTRAR'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.storage, size: 18),
                              label: const Text('Conferir banco de dados'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DatabaseInspectorScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      '---------- Desenvolvido por Go Up Sistemas ----------',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações do Sistema',
              onPressed: () {
                context.push('/config');
              },
            ),
          ),
        ],
      ),
    );
  }
}
