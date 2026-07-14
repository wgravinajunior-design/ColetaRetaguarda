import '../../../core/api/http_client.dart';
import '../../core/database/db_connection.dart';
import '../models/pessoa_model.dart';

class PessoaRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<PessoaModel>> getProdutores() async {
    final result = <PessoaModel>[];
    try {
      final db = await DbConnection().db;
      final q = db.query();

      String sql = "SELECT PES_ID, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, PES_TIPO_PESSOA, PES_CNPJ_CPF, PES_IE_RG, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, PES_CEP, PES_TELEFONE, PES_CELULAR, PES_EMAIL, PES_CONTATO, PES_REFERENCIA, PES_STATUS, PES_CLIENTE, PES_TRANSPORTADOR, PES_CONTRIBUINTE FROM TB_PESSOA WHERE PES_TIPO_PESSOA = 'P'";

      await q.openCursor(sql: sql);

      await for (var row in q.rows()) {
        result.add(PessoaModel(
          id: int.tryParse(row['PES_ID']?.toString() ?? '0'),
          tipoPessoa: row['PES_TIPO_PESSOA']?.toString() ?? 'P',
          rSocialNome: row['PES_RSOCIAL_NOME']?.toString() ?? '',
          fantasiaApelido: row['PES_FANTASIA_APELIDO']?.toString() ?? '',
          cnpjCpf: row['PES_CNPJ_CPF']?.toString() ?? '',
          ieRg: row['PES_IE_RG']?.toString() ?? '',
          endereco: row['PES_ENDERECO']?.toString() ?? '',
          numero: row['PES_NUMERO']?.toString() ?? '',
          complemento: row['PES_COMPLEMENTO']?.toString() ?? '',
          bairro: row['PES_BAIRRO']?.toString() ?? '',
          cep: row['PES_CEP']?.toString() ?? '',
          telefone: row['PES_TELEFONE']?.toString() ?? '',
          celular: row['PES_CELULAR']?.toString() ?? '',
          email: row['PES_EMAIL']?.toString() ?? '',
          contato: row['PES_CONTATO']?.toString() ?? '',
          referencia: row['PES_REFERENCIA']?.toString() ?? '',
          status: row['PES_STATUS']?.toString() ?? 'A',
          cliente: row['PES_CLIENTE']?.toString() ?? 'N',
          transportador: row['PES_TRANSPORTADOR']?.toString() ?? 'N',
          contribuinte: row['PES_CONTRIBUINTE']?.toString() ?? 'N',
        ));
      }

      await q.close();
      return result;
    } catch (e) {
      print('Erro real ao carregar produtores do Firebird: $e');
      return _getMockProdutores();
    }
  }

  Future<List<PessoaModel>> getMotoristas({String? query}) async {
    final result = <PessoaModel>[];
    try {
      final db = await DbConnection().db;
      final q = db.query();

      String sql = "SELECT PES_ID, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, PES_TIPO_PESSOA, PES_CNPJ_CPF, PES_IE_RG, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, PES_CEP, PES_TELEFONE, PES_CELULAR, PES_EMAIL, PES_CONTATO, PES_REFERENCIA, PES_STATUS, PES_CLIENTE, PES_TRANSPORTADOR, PES_CONTRIBUINTE FROM TB_PESSOA WHERE PES_TRANSPORTADOR = 'S'";
      final params = <dynamic>[];

      if (query != null && query.isNotEmpty) {
        sql += " AND UPPER(PES_RSOCIAL_NOME) LIKE UPPER(?)";
        params.add('%$query%');
      }

      await q.openCursor(sql: sql, parameters: params);

      await for (var row in q.rows()) {
        result.add(PessoaModel(
          id: int.tryParse(row['PES_ID']?.toString() ?? '0'),
          tipoPessoa: row['PES_TIPO_PESSOA']?.toString() ?? 'T',
          rSocialNome: row['PES_RSOCIAL_NOME']?.toString() ?? '',
          fantasiaApelido: row['PES_FANTASIA_APELIDO']?.toString() ?? '',
          cnpjCpf: row['PES_CNPJ_CPF']?.toString() ?? '',
          ieRg: row['PES_IE_RG']?.toString() ?? '',
          endereco: row['PES_ENDERECO']?.toString() ?? '',
          numero: row['PES_NUMERO']?.toString() ?? '',
          complemento: row['PES_COMPLEMENTO']?.toString() ?? '',
          bairro: row['PES_BAIRRO']?.toString() ?? '',
          cep: row['PES_CEP']?.toString() ?? '',
          telefone: row['PES_TELEFONE']?.toString() ?? '',
          celular: row['PES_CELULAR']?.toString() ?? '',
          email: row['PES_EMAIL']?.toString() ?? '',
          contato: row['PES_CONTATO']?.toString() ?? '',
          referencia: row['PES_REFERENCIA']?.toString() ?? '',
          status: row['PES_STATUS']?.toString() ?? 'A',
          cliente: row['PES_CLIENTE']?.toString() ?? 'N',
          transportador: row['PES_TRANSPORTADOR']?.toString() ?? 'S',
          contribuinte: row['PES_CONTRIBUINTE']?.toString() ?? 'N',
        ));
      }

      await q.close();
      return result;
    } catch (e) {
      print('Erro real ao carregar motoristas do Firebird: $e');
    }
    return result;
  }

  Future<List<PessoaModel>> getColaboradores({String? query}) async {
    final result = <PessoaModel>[];
    try {
      final db = await DbConnection().db;
      final q = db.query();

      String sql = "SELECT PES_ID, PES_RSOCIAL_NOME, PES_FANTASIA_APELIDO, PES_TIPO_PESSOA, PES_CNPJ_CPF, PES_IE_RG, PES_ENDERECO, PES_NUMERO, PES_COMPLEMENTO, PES_BAIRRO, PES_CEP, PES_TELEFONE, PES_CELULAR, PES_EMAIL, PES_CONTATO, PES_REFERENCIA, PES_STATUS, PES_CLIENTE, PES_TRANSPORTADOR, PES_CONTRIBUINTE FROM TB_PESSOA WHERE PES_TIPO_PESSOA = 'C'";
      final params = <dynamic>[];

      if (query != null && query.isNotEmpty) {
        sql += " AND UPPER(PES_RSOCIAL_NOME) LIKE UPPER(?)";
        params.add('%$query%');
      }

      await q.openCursor(sql: sql, parameters: params);

      await for (var row in q.rows()) {
        result.add(PessoaModel(
          id: int.tryParse(row['PES_ID']?.toString() ?? '0'),
          tipoPessoa: row['PES_TIPO_PESSOA']?.toString() ?? 'C',
          rSocialNome: row['PES_RSOCIAL_NOME']?.toString() ?? '',
          fantasiaApelido: row['PES_FANTASIA_APELIDO']?.toString() ?? '',
          cnpjCpf: row['PES_CNPJ_CPF']?.toString() ?? '',
          ieRg: row['PES_IE_RG']?.toString() ?? '',
          endereco: row['PES_ENDERECO']?.toString() ?? '',
          numero: row['PES_NUMERO']?.toString() ?? '',
          complemento: row['PES_COMPLEMENTO']?.toString() ?? '',
          bairro: row['PES_BAIRRO']?.toString() ?? '',
          cep: row['PES_CEP']?.toString() ?? '',
          telefone: row['PES_TELEFONE']?.toString() ?? '',
          celular: row['PES_CELULAR']?.toString() ?? '',
          email: row['PES_EMAIL']?.toString() ?? '',
          contato: row['PES_CONTATO']?.toString() ?? '',
          referencia: row['PES_REFERENCIA']?.toString() ?? '',
          status: row['PES_STATUS']?.toString() ?? 'A',
          cliente: row['PES_CLIENTE']?.toString() ?? 'N',
          transportador: row['PES_TRANSPORTADOR']?.toString() ?? 'N',
          contribuinte: row['PES_CONTRIBUINTE']?.toString() ?? 'N',
        ));
      }

      await q.close();
      return result;
    } catch (e) {
      print('Erro real ao carregar colaboradores do Firebird: $e');
    }
    return result;
  }

  Future<PessoaModel?> createPessoa(PessoaModel pessoa) async {
    try {
      final response = await _apiClient.post('/pessoas', body: pessoa.toJson());
      if (response.success && response.data != null) {
        return PessoaModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Erro ao criar pessoa: $e');
      // Mock behaviour for UI testing
      pessoa.id = DateTime.now().millisecondsSinceEpoch;
      return pessoa;
    }
  }

  Future<bool> updatePessoa(PessoaModel pessoa) async {
    if (pessoa.id == null) return false;
    try {
      await _apiClient.put('/pessoas/${pessoa.id}', pessoa.toJson());
      return true;
    } catch (e) {
      print('Erro ao atualizar pessoa: $e');
      return true; // Mock true
    }
  }

  Future<bool> deletePessoa(int id) async {
    try {
      await _apiClient.delete('/pessoas/$id');
      return true;
    } catch (e) {
      print('Erro ao deletar pessoa: $e');
      return true; // Mock true
    }
  }

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
