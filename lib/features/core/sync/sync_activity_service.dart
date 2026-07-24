import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/cache/cache_manager.dart';

/// Uma requisição do app mobile, para exibição ao vivo.
class SyncActivity {
  final String descricao;
  final String metodo;
  final String rota;
  final int? registros;
  final bool sucesso;
  final DateTime quando;

  SyncActivity({
    required this.descricao,
    required this.metodo,
    required this.rota,
    required this.sucesso,
    this.registros,
    DateTime? quando,
  }) : quando = quando ?? DateTime.now();

  /// Verdadeiro quando o mobile está gravando algo aqui, e não só lendo.
  bool get eEnvio => metodo != 'GET';
}

/// Ponte entre o servidor HTTP e a interface.
///
/// O servidor roda no isolate principal, então basta um singleton
/// [ChangeNotifier] para a tela reagir ao que o celular está fazendo — sem
/// polling e sem o usuário precisar sair da tela e voltar.
class SyncActivityService extends ChangeNotifier {
  static final SyncActivityService _instance = SyncActivityService._();
  factory SyncActivityService() => _instance;
  SyncActivityService._();

  static const _maxEventos = 6;

  /// Depois deste tempo sem requisição, considera a sincronização encerrada.
  static const _ocioso = Duration(seconds: 4);

  final List<SyncActivity> _eventos = [];
  Timer? _timerOcioso;
  bool _ativo = false;
  int _revisaoDados = 0;

  /// Eventos recentes, do mais novo para o mais antigo.
  List<SyncActivity> get eventos => List.unmodifiable(_eventos);

  /// Verdadeiro enquanto o celular está sincronizando agora.
  bool get ativo => _ativo;

  /// Muda a cada gravação vinda do mobile. As telas observam este número para
  /// se recarregarem sozinhas quando o celular altera algo no ERP.
  int get revisaoDados => _revisaoDados;

  /// Chamado pelo servidor a cada requisição do mobile.
  void registrar(SyncActivity evento) {
    _eventos.insert(0, evento);
    if (_eventos.length > _maxEventos) _eventos.removeLast();
    _ativo = true;

    // Uma escrita do mobile torna obsoleto o que as telas já carregaram: sem
    // isto o cache de 10 minutos dos ViewModels continuaria servindo o valor
    // anterior mesmo depois de sair da tela e voltar.
    if (evento.eEnvio && evento.sucesso) {
      CacheManager().clear();
      _revisaoDados++;
    }

    _timerOcioso?.cancel();
    _timerOcioso = Timer(_ocioso, () {
      _ativo = false;
      notifyListeners();
    });

    notifyListeners();
  }

  void limpar() {
    _eventos.clear();
    _ativo = false;
    _timerOcioso?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timerOcioso?.cancel();
    super.dispose();
  }
}
