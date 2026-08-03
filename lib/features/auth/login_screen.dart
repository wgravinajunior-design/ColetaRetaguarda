import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import '../../core/app_info.dart';
import '../../core/update/verificador_atualizacao.dart';
import '../core/config/config_service.dart';
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
  String _statusMensagem = '';

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();

    // Checagem de versão na abertura. Precisa sair daqui, e não do builder do
    // MaterialApp: lá o contexto fica acima do Navigator e o showDialog falha
    // sem avisar — o aviso de atualização simplesmente nunca aparecia.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      verificarAtualizacaoAoAbrir(context);
    });
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMensagem = 'Conectando à base de dados...';
    });

    try {
      // 1) Valida conexão com banco de dados (Firebird)
      final conectado = await DbConnection().testarConexao();
      if (!conectado) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMensagem = '';
          _errorMessage =
              'Sem conexão com a base de dados configurada.\n'
              'Verifique host, porta e caminho nas Configurações.';
        });
        return;
      }

      // 2) Autentica contra a base de dados
      if (!mounted) return;
      setState(() => _statusMensagem = 'Verificando usuário e senha...');
      final authService = context.read<AuthService>();
      final loginError = await authService.login(username, password);

      if (!mounted) return;

      if (loginError == null) {
        // Login bem-sucedido
        setState(() => _statusMensagem = 'Entrando...');
        // Sistema entra em tela cheia após autenticar
        await WindowService.modoApp();
        if (mounted) context.go('/dashboard');
      } else {
        setState(() {
          _isLoading = false;
          _statusMensagem = '';
          _errorMessage = loginError;
          // Limpa campo de senha por segurança
          _passwordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMensagem = '';
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
      body: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
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
                          Image.file(
                            File(logoPath),
                            height: 80,
                            fit: BoxFit.contain,
                          )
                        else
                          const Icon(
                            Icons.business_center,
                            size: 56,
                            color: Colors.blue,
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'ColetaUp',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$appVersao',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.red.shade100,
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          onSubmitted: (_) =>
                              !_isLoading ? _handleLogin() : null,
                          decoration: const InputDecoration(
                            labelText: 'Usuário',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
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
                          onSubmitted: (_) =>
                              !_isLoading ? _handleLogin() : null,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('ENTRAR'),
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey[500]!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _statusMensagem,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Configuração fica abaixo do cartão, discreta: o botão no
              // topo empurrava o conteúdo e deixava uma faixa vazia acima.
              // Diagnóstico do banco e logo moraram aqui e foram para
              // dentro de Configurações, junto do resto dos ajustes.
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Configurações'),
                onPressed: () => context.push('/config'),
              ),
              const SizedBox(height: 24),
              Text(
                'Go Up Sistemas',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
