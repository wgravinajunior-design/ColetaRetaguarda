import 'package:flutter/material.dart';
import '../models/relatorio.dart';
import 'relatorio_detalhe_screen.dart';

/// Menu de relatórios, agrupado por módulo.
class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(title: const Text('Relatórios'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final modulo in ModuloRelatorio.values) ...[
            _Cabecalho(modulo: modulo),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Cartões de ~300px: 1 coluna em janela estreita, mais conforme sobra espaço.
                final colunas = (constraints.maxWidth / 300).floor().clamp(
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
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 82,
                  ),
                  itemCount: itens.length,
                  itemBuilder: (context, i) => _CardRelatorio(def: itens[i]),
                );
              },
            ),
            const SizedBox(height: 20),
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: modulo.cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(modulo.icone, color: modulo.cor, size: 17),
        ),
        const SizedBox(width: 8),
        Text(
          modulo.titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: modulo.cor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey.shade200)),
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
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RelatorioDetalheScreen(def: def)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: def.modulo.cor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(def.icone, color: def.modulo.cor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      def.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
