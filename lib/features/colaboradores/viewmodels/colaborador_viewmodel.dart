import 'package:flutter/foundation.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../produtores/repositories/pessoa_repository.dart';

class ColaboradorViewModel extends ChangeNotifier {
  final PessoaRepository _repository = PessoaRepository();
  
  List<PessoaModel> colaboradores = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchColaboradores() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.getProdutores(); 
      // Filtro para funcionário
      colaboradores = data.where((p) => p.tipoPessoa == 'F' && p.transportador == 'N').toList();
      
      if (colaboradores.isEmpty) {
        colaboradores.add(
          PessoaModel(
            id: 20,
            tipoPessoa: 'F',
            rSocialNome: 'Ana Carolina Administrativo',
            fantasiaApelido: 'Ana',
            cnpjCpf: '444.555.666-77',
            ieRg: 'MG-998877',
            endereco: 'Rua Central',
            numero: '45',
            complemento: '',
            bairro: 'Centro',
            cep: '35000-000',
            telefone: '(31) 3333-1234',
            celular: '',
            email: 'ana@empresa.com',
            contato: '',
            referencia: '',
            status: 'A',
            cliente: 'N',
            transportador: 'N',
            contribuinte: 'N',
          )
        );
      }
    } catch (e) {
      errorMessage = 'Erro ao carregar colaboradores: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveColaborador(PessoaModel colaborador) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      if (colaborador.id == null) {
        final novo = await _repository.createPessoa(colaborador);
        if (novo != null) {
          colaboradores.add(novo);
          success = true;
        }
      } else {
        success = await _repository.updatePessoa(colaborador);
        if (success) {
          final index = colaboradores.indexWhere((p) => p.id == colaborador.id);
          if (index != -1) {
            colaboradores[index] = colaborador;
          }
        }
      }
    } catch (e) {
      errorMessage = 'Erro ao salvar colaborador: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteColaborador(int id) async {
    isLoading = true;
    notifyListeners();

    bool success = false;
    try {
      success = await _repository.deletePessoa(id);
      if (success) {
        colaboradores.removeWhere((p) => p.id == id);
      }
    } catch (e) {
      errorMessage = 'Erro ao deletar colaborador: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return success;
  }
}
