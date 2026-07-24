import 'package:flutter/material.dart';
import '../models/relatorio.dart';
import 'relatorio_detalhe_screen.dart';

/// Menu de relatórios, agrupado por módulo.
class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final modulo in ModuloRelatorio.values) ...[
            _Cabecalho(modulo: modulo),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                // Cartões de ~320px: 1 coluna em janela estreita, mais conforme sobra espaço.
                final colunas = (constraints.maxWidth / 320).floor().clamp(
                  1,
                  4,
                );
                final itens = relatoriosDisponiveis
                    .where((r) => r.modulo == modulo)
                    .toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: colunas,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 96,
                  ),
                  itemCount: itens.length,
                  itemBuilder: (context, i) => _CardRelatorio(def: itens[i]),
                );
              },
            ),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.modulo});

  final ModuloRelatorio modulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: modulo.cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(modulo.icone, color: modulo.cor, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          modulo.titulo,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: modulo.cor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: modulo.cor.withValues(alpha: 0.25))),
      ],
    );
  }
}

class _CardRelatorio extends StatelessWidget {
  const _CardRelatorio({required this.def});

  final DefinicaoRelatorio def;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RelatorioDetalheScreen(def: def)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(def.icone, color: def.modulo.cor, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      def.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      def.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
