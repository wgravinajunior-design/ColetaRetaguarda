import '../../../core/api/http_client.dart';
import '../../core/database/daos/pessoa_dao.dart';
import '../../core/database/sync_service.dart';
import '../models/pessoa_model.dart';

class PessoaRepository {
  final ApiClient _apiClient = ApiClient();
  final PessoaDao _dao = PessoaDao();
  final SyncService _syncService = SyncService();

  Future<List<PessoaModel>> getProdutores({String? query}) async {
    try {
      final response = await _apiClient.get('/coleta/pessoas?tipo=P${query != null ? '&q=$query' : ''}');
      if (response.success && response.data is List) {
        final produtores = (response.data as List)
            .map((p) => PessoaModel.fromJson(p as Map<String, dynamic>))
            .toList();
        // Sincroniza com banco local
        for (var p in produtores) {
          await _dao.insert(p);
        }
        return produtores;
      }
    } catch (e) {
      print('Erro ao carregar produtores da API: $e');
    }

    // Fallback: tenta carregar do SQLite
    try {
      return await _dao.getProdutores();
    } catch (e) {
      print('Erro ao carregar produtores do SQLite: $e');
    }

    return _getMockProdutores();
  }

  Future<List<PessoaModel>> getMotoristas({String? query}) async {
    try {
      final response = await _apiClient.get('/coleta/motoristas${query != null ? '?q=$query' : ''}');
      if (response.success && response.data is List) {
        final motoristas = (response.data as List)
            .map((m) => PessoaModel.fromJson(m as Map<String, dynamic>))
            .toList();
        for (var m in motoristas) {
          await _dao.insert(m);
        }
        return motoristas;
      }
    } catch (e) {
      print('Erro ao carregar motoristas da API: $e');
    }

    try {
      return await _dao.getMotoristas();
    } catch (e) {
      print('Erro ao carregar motoristas do SQLite: $e');
    }

    return [];
  }

  Future<List<PessoaModel>> getColaboradores({String? query}) async {
    try {
      final response = await _apiClient.get('/coleta/colaboradores${query != null ? '?q=$query' : ''}');
      if (response.success && response.data is List) {
        final colaboradores = (response.data as List)
            .map((c) => PessoaModel.fromJson(c as Map<String, dynamic>))
            .toList();
        for (var c in colaboradores) {
          await _dao.insert(c);
        }
        return colaboradores;
      }
    } catch (e) {
      print('Erro ao carregar colaboradores da API: $e');
    }

    try {
      return await _dao.getColaboradores();
    } catch (e) {
      print('Erro ao carregar colaboradores do SQLite: $e');
    }

    return [];
  }

  Future<PessoaModel?> createPessoa(PessoaModel pessoa) async {
    try {
      final response = await _apiClient.post('/coleta/pessoas', body: pessoa.toJson());
      if (response.success && response.data != null) {
        final created = PessoaModel.fromJson(response.data as Map<String, dynamic>);
        await _dao.insert(created);
        return created;
      }
    } catch (e) {
      print('Erro ao criar pessoa na API: $e');
    }

    // Fallback: salva localmente e enfileira para sincronização
    pessoa.id ??= DateTime.now().millisecondsSinceEpoch;
    await _dao.insert(pessoa);
    await _syncService.queueOperation(
      tabela: 'tb_pessoa',
      operacao: 'CREATE',
      registroId: pessoa.id,
      dados: pessoa.toJson(),
    );
    return pessoa;
  }

  Future<bool> updatePessoa(PessoaModel pessoa) async {
    if (pessoa.id == null) return false;

    try {
      final response = await _apiClient.put('/coleta/pessoas/${pessoa.id}', body: pessoa.toJson());
      if (response.success) {
        await _dao.update(pessoa);
        return true;
      }
    } catch (e) {
      print('Erro ao atualizar pessoa na API: $e');
    }

    // Fallback: atualiza localmente e enfileira
    await _dao.update(pessoa);
    await _syncService.queueOperation(
      tabela: 'tb_pessoa',
      operacao: 'UPDATE',
      registroId: pessoa.id,
      dados: pessoa.toJson(),
    );
    return true;
  }

  Future<bool> deletePessoa(int id) async {
    try {
      await _apiClient.delete('/coleta/pessoas/$id');
      await _dao.delete(id);
      return true;
    } catch (e) {
      print('Erro ao deletar pessoa na API: $e');
    }

    // Fallback: deleta localmente e enfileira
    await _dao.delete(id);
    await _syncService.queueOperation(
      tabela: 'tb_pessoa',
      operacao: 'DELETE',
      registroId: id,
      dados: {'id': id},
    );
    return true;
  }

  List<PessoaModel> getMockProdutores() => _getMockProdutores();

  List<PessoaModel> _getMockProdutores() {
    return [
      PessoaModel(
        id: 1,
        tipoPessoa: 'P',
        rSocialNome: 'João da Silva',
        fantasiaApelido: 'Fazenda Boa Vista',
        cnpjCpf: '123.456.789-00',
        ieRg: 'MG-123456',
        endereco: 'Rodovia MG 10, Km 20',
        numero: 'S/N',
        complemento: 'Fazenda',
        bairro: 'Zona Rural',
        cep: '35000-000',
        telefone: '(31) 3333-4444',
        celular: '(31) 99999-8888',
        email: 'joao@fazenda.com',
        contato: 'João',
        referencia: 'Perto da ponte',
        status: 'A',
        cliente: 'S',
        transportador: 'N',
        contribuinte: 'S',
      ),
      PessoaModel(
        id: 2,
        tipoPessoa: 'P',
        rSocialNome: 'Maria Souza',
        fantasiaApelido: 'Sítio das Flores',
        cnpjCpf: '987.654.321-00',
        ieRg: 'MG-654321',
        endereco: 'Estrada Velha, Km 5',
        numero: '100',
        complemento: '',
        bairro: 'Vila Rural',
        cep: '35000-000',
        telefone: '(31) 3333-5555',
        celular: '(31) 98888-7777',
        email: 'maria@sitio.com',
        contato: 'Maria',
        referencia: '',
        status: 'A',
        cliente: 'S',
        transportador: 'N',
        contribuinte: 'N',
      ),
    ];
  }
}
