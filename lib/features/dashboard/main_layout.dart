import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../core/config/config_service.dart';
import '../core/widgets/sync_status_widget.dart';

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
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              children: [
                DrawerHeader(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (logoPath.isNotEmpty && File(logoPath).existsSync())
                        Image.file(File(logoPath), height: 60, fit: BoxFit.contain)
                      else
                        const Icon(Icons.business_center, size: 48, color: Colors.blue),
                      const SizedBox(height: 8),
                      const Text(
                        'ColetaUp',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
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
                  icon: Icons.badge,
                  title: 'Colaboradores',
                  color: Colors.deepPurple,
                  onTap: () => context.go('/colaboradores'),
                ),
                _MenuTile(
                  icon: Icons.attach_money,
                  title: 'Financeiro',
                  color: Colors.red,
                  onTap: () => context.go('/financeiro'),
                ),
                const Spacer(),
                const Divider(),
                _MenuTile(
                  icon: Icons.logout,
                  title: 'Sair',
                  color: Colors.grey,
                  onTap: () {
                    context.read<AuthService>().logout();
                    context.go('/login');
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
                Expanded(child: child),
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
          color: _isHovered ? widget.color.withOpacity(0.1) : Colors.transparent,
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
