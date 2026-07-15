import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        if (connectivity.isSyncing) {
          return Container(
            color: Colors.blue.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sincronizando dados offline...',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }

        if (!connectivity.isOnline) {
          return Container(
            color: Colors.orange.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modo offline ${connectivity.pendingCount > 0 ? '(${connectivity.pendingCount} pendente${connectivity.pendingCount != 1 ? 's' : ''})' : ''}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (connectivity.pendingCount > 0 && !connectivity.isSyncing) {
          return Container(
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.cloud_upload, size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${connectivity.pendingCount} item${connectivity.pendingCount != 1 ? 'ns' : ''} aguardando sincronização',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => connectivity.syncPending(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sincronizar agora'),
                ),
              ],
            ),
          );
        }

        // Online e sem pendências: mantém o botão "Sincronizar agora" disponível.
        return Container(
          color: Colors.green.shade100,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.cloud_done, size: 18, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sincronizado',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => connectivity.syncPending(),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sincronizar agora'),
              ),
            ],
          ),
        );
      },
    );
  }
}
