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
    // Validação de entrada
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Digite seu usuário';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Digite sua senha';
      });
      return;
    }

    if (password.length < 3) {
      setState(() {
        _errorMessage = 'Senha inválida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1) Valida conexão com banco de dados (Firebird)
      final conectado = await DbConnection().testarConexao();
      if (!conectado) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sem conexão com a base de dados configurada.\n'
              'Verifique host, porta e caminho nas Configurações.';
        });
        return;
      }

      // 2) Autentica contra a base de dados
      if (!mounted) return;
      final authService = context.read<AuthService>();
      final loginError = await authService.login(username, password);

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
          // Limpa campo de senha por segurança
          _passwordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro inesperado durante login. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final logoPath = config.logoPath;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (logoPath.isNotEmpty && File(logoPath).existsSync())
                              Image.file(File(logoPath), height: 80, fit: BoxFit.contain)
                            else
                              const Icon(Icons.business_center, size: 56, color: Colors.blue),
                            const SizedBox(height: 12),
                            Text('ColetaUp', style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text('v1.17.0', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(height: 20),
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.red.shade100,
                                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
                              ),
                            if (_errorMessage != null) const SizedBox(height: 12),
                            TextField(
                              controller: _usernameController,
                              enabled: !_isLoading,
                              onSubmitted: (_) => !_isLoading ? _handleLogin() : null,
                              decoration: const InputDecoration(
                                labelText: 'Usuário',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                helperText: 'Digite seu nome de usuário',
                              ),
                              textInputAction: TextInputAction.next,
                              autofocus: true,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: true,
                              onSubmitted: (_) => !_isLoading ? _handleLogin() : null,
                              decoration: const InputDecoration(
                                labelText: 'Senha',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                helperText: 'Sua senha segura',
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('ENTRAR'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.storage, size: 16),
                              label: const Text('Conferir banco de dados', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const DatabaseInspectorScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '---------- Desenvolvido por Go Up Sistemas ----------',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.settings, size: 24),
              tooltip: 'Configurações do Sistema',
              onPressed: () => context.push('/config'),
            ),
          ),
        ],
      ),
    );
  }
}
