import 'package:flutter/material.dart';
import '../logging/app_logger.dart';

/// Estados de conexão
enum ConnectionStatus {
  online,
  offline,
  loading,
}

/// Banner que mostra o status de conexão
class ConnectionStatusBanner extends StatefulWidget {
  final Widget child;
  final Duration checkInterval;

  const ConnectionStatusBanner({
    required this.child,
    this.checkInterval = const Duration(seconds: 5),
    super.key,
  });

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  final AppLogger _logger = AppLogger();
  ConnectionStatus _status = ConnectionStatus.online;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    while (mounted) {
      try {
        // Simula uma verificação de conexão
        // Em produção, isso usaria o connectivity_plus package
        if (_status == ConnectionStatus.offline) {
          setState(() {
            _status = ConnectionStatus.online;
          });
          _logger.info('ConnectionStatusBanner', 'Conexão restaurada');
        }
      } catch (e) {
        if (_status == ConnectionStatus.online) {
          setState(() {
            _status = ConnectionStatus.offline;
          });
          _logger.warning('ConnectionStatusBanner', 'Conexão perdida');
        }
      }
      await Future.delayed(widget.checkInterval);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_status == ConnectionStatus.offline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange[700],
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sem conexão com a internet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
