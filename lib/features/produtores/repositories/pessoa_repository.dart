import 'package:flutter/foundation.dart';
import '../../../core/api/http_client.dart';
import '../../core/database/daos/pessoa_dao.dart';
import '../../core/database/firebird_service.dart';
import '../models/pessoa_model.dart';

class PessoaRepository {
  final ApiClient _apiClient = ApiClient();
  final PessoaDao _dao = PessoaDao();
  final FirebirdService _firebird = FirebirdService();

  Future<List<PessoaModel>> getProdutores({String? query, String? status = 'A'}) async {
    // Fonte primária: base Firebird configurada (TB_PESSOA, PES_FORNECEDOR='S')
    try {
      final produtores = await _firebird.getProdutores(status: status);
      if (query == null || query.isEmpty) return produtores;
      final q = query.toLowerCase();
      return produtores
          .where((p) =>
              p.rSocialNome.toLowerCase().contains(q) ||
              p.cnpjCpf.toLowerCase().contains(q))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar produtores do Firebird: $e');
    }

    // Fallback: tenta carregar do SQLite
    try {
      return await _dao.getProdutores();
    } catch (e) {
      debugPrint('Erro ao carregar produtores do SQLite: $e');
    }

    return [];
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
      debugPrint('Erro ao carregar motoristas da API: $e');
    }

    try {
      return await _dao.getMotoristas();
    } catch (e) {
      debugPrint('Erro ao carregar motoristas do SQLite: $e');
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
      debugPrint('Erro ao carregar colaboradores da API: $e');
    }

    try {
      return await _dao.getColaboradores();
    } catch (e) {
      debugPrint('Erro ao carregar colaboradores do SQLite: $e');
    }

    return [];
  }

  Future<PessoaModel?> createPessoa(PessoaModel pessoa) async {
    // Grava direto na base Firebird (TB_PESSOA, marcado como fornecedor)
    return await _firebird.criarProdutor(pessoa);
  }

  Future<bool> updatePessoa(PessoaModel pessoa) async {
    if (pessoa.id == null) return false;
    return await _firebird.atualizarProdutor(pessoa);
  }

  Future<bool> deletePessoa(int id) async {
    // Exclusão lógica no ERP (marca inativo — não remove o registro)
    return await _firebird.excluirProdutor(id);
  }

}
