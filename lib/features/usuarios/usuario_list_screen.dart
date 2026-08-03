import 'package:flutter/material.dart';
import '../core/config/config_service.dart';
import '../motoristas/models/motorista_model.dart';
import '../motoristas/repositories/motorista_repository.dart';
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
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: const Text('Usuários'),
        elevation: 0,
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
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.storage, color: Colors.blue[700], size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estes são os usuários da base em uso',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ConfigService().caminhoBase,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_carregando)
                      Text(
                        '$ativos ativo${ativos == 1 ? "" : "s"}'
                        ' de ${_usuarios.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
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
      return Center(
        child: Text(
          'Nenhum usuário nesta base.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: _usuarios.length,
      itemBuilder: (_, i) {
        final u = _usuarios[i];
        final cor = u.ativo
            ? (u.administrador ? Colors.indigo : Colors.blueGrey)
            : Colors.grey;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                u.administrador ? Icons.shield_outlined : Icons.person_outline,
                color: cor,
                size: 20,
              ),
            ),
            title: Text(
              u.nome.isEmpty ? u.login : u.nome,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: u.ativo ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              'Login: ${u.login}'
              '  ·  ${u.administrador ? "Administrador" : "Operador"}'
              '${u.ativo ? "" : "  ·  inativo"}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Colors.blueGrey[600],
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Editar',
                  onPressed: () => _editar(u),
                ),
                if (u.ativo)
                  IconButton(
                    icon: const Icon(Icons.block_outlined, size: 18),
                    color: Colors.red[300],
                    visualDensity: VisualDensity.compact,
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

  /// Motorista vinculado. Define o que o app do celular mostra a este usuário.
  int? _motoristaId;
  List<MotoristaModel> _motoristas = const [];
  bool _carregandoMotoristas = true;

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
    _motoristaId = u?.motoristaId;
    _carregarMotoristas();
  }

  Future<void> _carregarMotoristas() async {
    try {
      final lista = await MotoristaRepository().getMotoristas();
      if (!mounted) return;
      setState(() {
        _motoristas = lista;
        // O motorista guardado pode ter sido inativado depois do vínculo: sem
        // isto o Dropdown receberia um value fora das opções e estouraria.
        if (_motoristaId != null &&
            !lista.any((m) => m.id == _motoristaId)) {
          _motoristaId = null;
        }
        _carregandoMotoristas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoMotoristas = false);
    }
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
        motoristaId: _motoristaId,
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

  InputDecoration _decoracao(String label, {String? helper, IconData? icone}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      helperText: helper,
      helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
      helperMaxLines: 2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      prefixIcon: icone != null ? Icon(icone, size: 18) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _novo ? 'Novo usuário' : 'Editar usuário',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nome,
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoracao('Nome *', icone: Icons.badge_outlined),
                    validator: (t) => (t == null || t.trim().isEmpty)
                        ? 'Informe o nome'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _login,
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoracao('Login *', icone: Icons.person_outline),
                    validator: (t) => (t == null || t.trim().isEmpty)
                        ? 'Informe o login'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _senha,
                    style: const TextStyle(fontSize: 13),
                    decoration: _decoracao(
                      _novo ? 'Senha *' : 'Nova senha',
                      helper: _novo
                          ? null
                          : 'Deixe em branco para manter a senha atual',
                      icone: Icons.lock_outline,
                    ),
                    validator: (t) => (_novo && (t == null || t.trim().isEmpty))
                        ? 'Informe a senha'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  // Vínculo com o motorista: é o que restringe, no celular, as
                  // rotas que este usuário enxerga. Em branco, ele vê todas.
                  if (_carregandoMotoristas)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: _motoristaId,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: _decoracao(
                        'Motorista vinculado',
                        helper: 'No celular, mostra só as rotas deste motorista',
                        icone: Icons.local_shipping_outlined,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Nenhum — vê todas as rotas'),
                        ),
                        ..._motoristas.map(
                          (m) => DropdownMenuItem<int?>(
                            value: m.id,
                            child: Text(
                              m.nome ?? 'Motorista ${m.id}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _motoristaId = v),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: const Text('Administrador', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: const Text(
                            'Pode cadastrar e alterar dados pelo celular',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _administrador,
                          onChanged: (v) => setState(() => _administrador = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: const Text('Ativo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: const Text(
                            'Desligado, o usuário não consegue entrar',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _ativo,
                          onChanged: (v) => setState(() => _ativo = v),
                        ),
                      ],
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _erro!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _salvando ? null : _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D4F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Salvar',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
