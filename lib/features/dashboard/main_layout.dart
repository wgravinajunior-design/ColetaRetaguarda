import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../core/config/config_service.dart';
import '../core/widgets/sync_status_widget.dart';
import '../core/window/window_service.dart';
import '../../core/app_info.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigService>();
    final logoPath = config.logoPath;

    return Scaffold(
      body: Row(
        children: [
          // Menu Lateral (Side Navigation)
          Container(
            width: 250,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (logoPath.isNotEmpty && File(logoPath).existsSync())
                        Image.file(
                          File(logoPath),
                          height: 60,
                          fit: BoxFit.contain,
                        )
                      else
                        const Icon(
                          Icons.business_center,
                          size: 48,
                          color: Colors.blue,
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'ColetaUp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _MenuTile(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        color: Colors.blue,
                        onTap: () => context.go('/dashboard'),
                      ),
                      _MenuTile(
                        icon: Icons.people,
                        title: 'Produtores',
                        color: Colors.green,
                        onTap: () => context.go('/produtores'),
                      ),
                      _MenuTile(
                        icon: Icons.local_shipping,
                        title: 'Motoristas',
                        color: Colors.orange,
                        onTap: () => context.go('/motoristas'),
                      ),
                      _MenuTile(
                        icon: Icons.local_shipping,
                        title: 'Rotas',
                        color: Colors.teal,
                        onTap: () => context.go('/rotas'),
                      ),
                      _MenuTile(
                        icon: Icons.agriculture,
                        title: 'Coleta',
                        color: Colors.brown,
                        onTap: () => context.go('/coleta'),
                      ),
                      _MenuTile(
                        icon: Icons.ac_unit,
                        title: 'Resfriadores',
                        color: Colors.cyan,
                        onTap: () => context.go('/resfriadores'),
                      ),
                      _MenuTile(
                        icon: Icons.attach_money,
                        title: 'Financeiro',
                        color: Colors.red,
                        onTap: () => context.go('/financeiro'),
                      ),
                      _MenuTile(
                        icon: Icons.payments,
                        title: 'Pagamentos',
                        color: Colors.green,
                        onTap: () => context.go('/pagamentos'),
                      ),
                      _MenuTile(
                        icon: Icons.assessment,
                        title: 'Relatórios',
                        color: Colors.teal,
                        onTap: () => context.go('/relatorios'),
                      ),
                      _MenuTile(
                        icon: Icons.sync,
                        title: 'Sincronização',
                        color: Colors.indigo,
                        onTap: () => context.go('/sync'),
                      ),
                      _MenuTile(
                        icon: Icons.manage_accounts,
                        title: 'Usuários',
                        color: Colors.blueGrey,
                        onTap: () => context.go('/usuarios'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Versão à vista no menu: é o que se confere primeiro quando
                // se desconfia de que a atualização não chegou.
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Versão $appVersao',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.logout,
                  title: 'Sair',
                  color: Colors.grey,
                  onTap: () async {
                    context.read<AuthService>().logout();
                    await WindowService.modoLogin();
                    if (context.mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Área de Conteúdo
          Expanded(
            child: Column(
              children: [
                const SyncStatusWidget(),
                Expanded(
                  // A logo da empresa fica no canto inferior direito de toda
                  // tela, apagada o bastante para não competir com o conteúdo.
                  child: Stack(
                    children: [
                      Positioned.fill(child: child),
                      if (logoPath.isNotEmpty && File(logoPath).existsSync())
                        Positioned(
                          right: 14,
                          bottom: 10,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.13,
                              child: Image.file(
                                File(logoPath),
                                height: 46,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(widget.icon, color: widget.color),
          title: Text(
            widget.title,
            style: TextStyle(
              color: _isHovered ? widget.color : Colors.black87,
              fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
