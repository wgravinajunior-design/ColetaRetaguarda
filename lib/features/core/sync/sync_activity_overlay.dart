import 'package:flutter/material.dart';
import 'sync_activity_service.dart';

/// Card que sobe no canto inferior direito enquanto o celular sincroniza,
/// mostrando o que está indo e chegando.
///
/// Fica sobre toda a aplicação (envolve o `child` do MaterialApp), então
/// aparece em qualquer tela sem cada uma precisar saber do assunto.
class SyncActivityOverlay extends StatefulWidget {
  const SyncActivityOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<SyncActivityOverlay> createState() => _SyncActivityOverlayState();
}

class _SyncActivityOverlayState extends State<SyncActivityOverlay> {
  final _service = SyncActivityService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_aoMudar);
  }

  @override
  void dispose() {
    _service.removeListener(_aoMudar);
    super.dispose();
  }

  void _aoMudar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final eventos = _service.eventos;

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            // Fora de tela quando ocioso: o card desliza de baixo para cima.
            offset: _service.ativo ? Offset.zero : const Offset(0, 1.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _service.ativo ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_service.ativo,
                child: _Card(eventos: eventos),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.eventos});

  final List<SyncActivity> eventos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final enviando = eventos.any((e) => e.eEnvio);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: tema.cardColor,
      child: Container(
        width: 330,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enviando
                        ? 'Recebendo dados do celular'
                        : 'Sincronizando com o celular',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.smartphone, size: 16, color: Colors.blue.shade400),
              ],
            ),
            const SizedBox(height: 10),
            ...eventos.take(5).map(_linha),
          ],
        ),
      ),
    );
  }

  Widget _linha(SyncActivity e) {
    final cor = e.sucesso ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            e.sucesso
                ? (e.eEnvio ? Icons.arrow_downward : Icons.arrow_upward)
                : Icons.error_outline,
            size: 14,
            color: cor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.descricao,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (e.registros != null)
            Text(
              '${e.registros}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
        ],
      ),
    );
  }
}
