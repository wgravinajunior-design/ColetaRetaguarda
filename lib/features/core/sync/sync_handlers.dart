import '../database/sync_service.dart';

import '../../produtores/repositories/pessoa_repository.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../motoristas/repositories/motorista_repository.dart';
import '../../motoristas/models/motorista_model.dart';
import '../../veiculos/repositories/veiculo_repository.dart';
import '../../veiculos/models/veiculo_model.dart';
import '../../rotas/repositories/rota_repository.dart';
import '../../rotas/models/rota_model.dart';
import '../../resfriadores/repositories/resfriador_repository.dart';
import '../../resfriadores/models/resfriador_model.dart';
import '../../financeiro/repositories/financeiro_repository.dart';
import '../../financeiro/models/movimento_model.dart';
import '../../coleta/repositories/parada_repository.dart';
import '../../coleta/models/parada_model.dart';

/// Chaves de entidade usadas em [SyncService.queueOperation] / registerHandler.
/// Mantê-las centralizadas evita divergência entre quem enfileira e quem reprocessa.
class SyncEntities {
  static const produtor = 'produtor';
  static const motorista = 'motorista';
  static const veiculo = 'veiculo';
  static const rota = 'rota';
  static const resfriador = 'resfriador';
  static const movimento = 'movimento';
  static const parada = 'tb_parada';
}

int? _idOf(int? registroId, Map<String, dynamic> dados) =>
    registroId ?? (dados['id'] as int?);

/// Registra os handlers de replay de cada entidade no [SyncService] (singleton).
/// Deve ser chamado uma vez no bootstrap (main), antes de disparar o processamento
/// da fila. Cada handler reexecuta a escrita no repository/Firebird — se a base
/// ainda estiver indisponível, lança/retorna false e o item permanece pendente.
void registerSyncHandlers() {
  final sync = SyncService();

  sync.registerHandler(SyncEntities.produtor, (op, id, dados) async {
    final repo = PessoaRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.createPessoa(PessoaModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.updatePessoa(PessoaModel.fromJson(dados));
      case 'DELETE':
        return await repo.deletePessoa(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  sync.registerHandler(SyncEntities.motorista, (op, id, dados) async {
    final repo = MotoristaRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.createMotorista(MotoristaModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.updateMotorista(MotoristaModel.fromJson(dados));
      case 'DELETE':
        return await repo.deleteMotorista(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  sync.registerHandler(SyncEntities.veiculo, (op, id, dados) async {
    final repo = VeiculoRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.createVeiculo(VeiculoModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.updateVeiculo(VeiculoModel.fromJson(dados));
      case 'DELETE':
        return await repo.deleteVeiculo(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  sync.registerHandler(SyncEntities.rota, (op, id, dados) async {
    final repo = RotaRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.createRota(RotaModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.updateRota(RotaModel.fromJson(dados));
      case 'DELETE':
        return await repo.deleteRota(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  sync.registerHandler(SyncEntities.resfriador, (op, id, dados) async {
    final repo = ResfriadorRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.create(ResfriadorModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.update(ResfriadorModel.fromJson(dados));
      case 'DELETE':
        return await repo.delete(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  sync.registerHandler(SyncEntities.movimento, (op, id, dados) async {
    final repo = FinanceiroRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.createMovimento(MovimentoModel.fromJson(dados)) != null;
      case 'UPDATE':
        return await repo.updateMovimento(MovimentoModel.fromJson(dados));
      case 'DELETE':
        return await repo.deleteMovimento(_idOf(id, dados)!);
      default:
        return false;
    }
  });

  // Paradas: usa métodos "replay-only" que só tentam o Firebird (sem re-enfileirar),
  // evitando duplicar itens na fila caso a base ainda esteja offline.
  sync.registerHandler(SyncEntities.parada, (op, id, dados) async {
    final repo = ParadaRepository();
    switch (op) {
      case 'CREATE':
      case 'INSERT':
        return await repo.replayCriar(ParadaModel.fromJson(dados));
      case 'UPDATE':
        return await repo.replayAtualizarStatus(
          paradaId: _idOf(id, dados)!,
          novoStatus: dados['status'] as String,
          temperatura: (dados['temperatura'] as num?)?.toDouble(),
          volume: (dados['volume'] as num?)?.toDouble(),
          justificativa: dados['justificativa'] as String?,
          assinaturaBase64: dados['assinatura_base64'] as String?,
          fotoPath: dados['foto_path'] as String?,
        );
      default:
        return false;
    }
  });
}
