import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import '../core/config/config_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = context.read<AuthService>();
    final success = await authService.login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) context.go('/dashboard');
    } else {
      setState(() {
        _errorMessage = 'Credenciais inválidas ou erro de conexão.';
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
                              'v1.1.0',
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
