/// Constantes de endpoints da API ColetaERP
abstract class ApiEndpoints {
  // Base paths
  static const String _base = '/coleta';

  // Pessoas (Produtores, Motoristas, Colaboradores)
  static const String pessoas = '$_base/pessoas';
  static String pessoaById(int id) => '$pessoas/$id';

  // Movimento Conta (Financeiro)
  static const String movimentoConta = '$_base/movimento-conta';
  static String movimentoContaById(int id) => '$movimentoConta/$id';

  // Veículos
  static const String veiculos = '$_base/veiculos';
  static String veiculoById(int id) => '$veiculos/$id';

  // Rotas
  static const String rotas = '$_base/rotas';
  static String rotaById(int id) => '$rotas/$id';

  // Resfriadores
  static const String resfriadores = '$_base/resfriadores';
  static String resfriadorById(int id) => '$resfriadores/$id';

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';

  // Sync
  static const String syncQueue = '$_base/sync-queue';
  static String syncQueueStatus(int queueId) => '$syncQueue/$queueId';
}
