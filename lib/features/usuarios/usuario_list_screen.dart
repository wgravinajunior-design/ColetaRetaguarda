import 'package:flutter/material.dart';
import '../core/config/config_service.dart';
import 'usuario_service.dart';

/// Usuários que podem entrar no sistema.
///
/// Lê e grava direto na TB_USUARIO da base escolhida nas Configurações — a
/// mesma tabela que o ERP usa. Quem for cadastrado aqui entra no ERP também, e
/// quem o ERP cadastrou aparece aqui.
class UsuarioListScreen extends StatefulWidget {
  const UsuarioListScreen({super.key});

  @override
  State<UsuarioListScreen> createState() => _UsuarioListScreenState();
}

class _UsuarioListScreenState extends State<UsuarioListScreen> {
  final _service = UsuarioService();

  bool _carregando = true;
  String? _erro;
  List<UsuarioModel> _usuarios = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await _service.listar();
      if (mounted) setState(() => _usuarios = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editar([UsuarioModel? usuario]) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => _UsuarioDialog(usuario: usuario),
    );
    if (salvou == true) await _carregar();
  }

  Future<void> _desativar(UsuarioModel u) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar usuário'),
        content: Text(
          '${u.nome.isEmpty ? u.login : u.nome} deixará de conseguir entrar '
          'no sistema.\n\nO cadastro não é apagado — dá para reativar depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await _service.desativar(u.id!);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível desativar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativos = _usuarios.where((u) => u.ativo).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo usuário'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.storage, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estes são os usuários da base em uso',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ConfigService().caminhoBase,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_carregando)
                        Text(
                          '$ativos ativo${ativos == 1 ? "" : "s"}'
                          ' de ${_usuarios.length}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _corpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
              const SizedBox(height: 10),
              const Text('Não foi possível ler os usuários'),
              const SizedBox(height: 6),
              SelectableText(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (_usuarios.isEmpty) {
      return const Center(child: Text('Nenhum usuário nesta base.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: _usuarios.length,
      itemBuilder: (_, i) {
        final u = _usuarios[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.ativo
                  ? (u.administrador ? Colors.indigo : Colors.blueGrey)
                  : Colors.grey.shade400,
              child: Icon(
                u.administrador ? Icons.shield : Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              u.nome.isEmpty ? u.login : u.nome,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: u.ativo ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              'Login: ${u.login}'
              '  ·  ${u.administrador ? "Administrador" : "Operador"}'
              '${u.ativo ? "" : "  ·  inativo"}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Editar',
                  onPressed: () => _editar(u),
                ),
                if (u.ativo)
                  IconButton(
                    icon: const Icon(Icons.block, size: 20),
                    tooltip: 'Desativar',
                    onPressed: () => _desativar(u),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UsuarioDialog extends StatefulWidget {
  final UsuarioModel? usuario;
  const _UsuarioDialog({this.usuario});

  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = UsuarioService();

  late final TextEditingController _nome;
  late final TextEditingController _login;
  late final TextEditingController _senha;

  bool _administrador = false;
  bool _ativo = true;
  bool _salvando = false;
  String? _erro;

  bool get _novo => widget.usuario == null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nome = TextEditingController(text: u?.nome ?? '');
    _login = TextEditingController(text: u?.login ?? '');
    _senha = TextEditingController();
    _administrador = u?.administrador ?? false;
    _ativo = u?.ativo ?? true;
  }

  @override
  void dispose() {
    _nome.dispose();
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final emUso = await _service.loginEmUso(
        _login.text,
        ignorandoId: widget.usuario?.id,
      );
      if (emUso) {
        setState(() {
          _erro = 'Já existe um usuário com este login.';
          _salvando = false;
        });
        return;
      }

      final u = UsuarioModel(
        id: widget.usuario?.id,
        nome: _nome.text.trim(),
        login: _login.text.trim(),
        senha: _senha.text.trim(),
        administrador: _administrador,
        status: _ativo ? 'A' : 'I',
      );

      if (_novo) {
        await _service.criar(u);
      } else {
        await _service.atualizar(u);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível salvar: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_novo ? 'Novo usuário' : 'Editar usuário'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (t) => (t == null || t.trim().isEmpty)
                      ? 'Informe o nome'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _login,
                  decoration: const InputDecoration(
                    labelText: 'Login *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (t) => (t == null || t.trim().isEmpty)
                      ? 'Informe o login'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _senha,
                  decoration: InputDecoration(
                    labelText: _novo ? 'Senha *' : 'Nova senha',
                    helperText: _novo
                        ? null
                        : 'Deixe em branco para manter a senha atual',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (t) => (_novo && (t == null || t.trim().isEmpty))
                      ? 'Informe a senha'
                      : null,
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Administrador', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Pode cadastrar e alterar dados pelo celular',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _administrador,
                  onChanged: (v) => setState(() => _administrador = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Desligado, o usuário não consegue entrar',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _ativo,
                  onChanged: (v) => setState(() => _ativo = v),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _erro!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
