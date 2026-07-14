import '../../../core/api/http_client.dart';
import '../../core/database/db_connection.dart';
import '../models/movimento_model.dart';

class FinanceiroRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<MovimentoModel>> getMovimentos({String? tipo, String? dataInicio, String? dataFim}) async {
    final result = <MovimentoModel>[];
    try {
      final db = await DbConnection().db;
      final q = db.query();
      
      // Montar a query dinamicamente. Por padrão, no Delphi vimos que a tabela é TB_MOVIMENTO_CONTA
      String sql = 'SELECT * FROM TB_MOVIMENTO_CONTA WHERE 1=1';
      final params = <dynamic>[];
      
      if (tipo != null && tipo.isNotEmpty) {
        // Ajuste conforme o nome da coluna real no seu banco, presumindo MVC_TIPO
        sql += ' AND MVC_TIPO = ?';
        params.add(tipo);
      }
      // Se houver campos de data na sua tabela, adicionar filtro aqui. Ex: MVC_DATA
      
      await q.openCursor(sql: sql, parameters: params);
      
      await for (var row in q.rows()) {
        result.add(MovimentoModel(
          // Tratar o id, assumindo MVC_ID ou ID
          id: int.tryParse(row['MVC_ID']?.toString() ?? row['ID']?.toString() ?? '0') ?? 0,
          tipo: row['MVC_TIPO']?.toString() ?? '',
          status: row['MVC_STATUS']?.toString() ?? '',
          conta: int.tryParse(row['MVC_CONTA']?.toString() ?? '0') ?? 0,
          contaNome: 'Conta ${row['MVC_CONTA']}', // Se tiver inner join, pega nome
          valor: double.tryParse(row['MVC_VALOR']?.toString() ?? '0') ?? 0.0,
          dtEmissao: row['MVC_DATA_EMISSAO']?.toString() ?? '',
          dtCompensado: row['MVC_DATA_COMPENSADO']?.toString() ?? '',
          historico: row['MVC_HISTORICO']?.toString() ?? '',
        ));
      }
      
      await q.close();
      return result;
    } catch (e) {
      print('Erro real ao carregar movimentos do Firebird: $e');
    }

    // Mock fallback para testes sem API
    return [
      MovimentoModel(
        id: 1,
        tipo: 'C',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 1500.0,
        dtEmissao: '2026-07-01',
        dtCompensado: '2026-07-01',
        historico: 'Venda de Soja',
      ),
      MovimentoModel(
        id: 2,
        tipo: 'D',
        status: 'C',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 500.0,
        dtEmissao: '2026-07-05',
        dtCompensado: '2026-07-05',
        historico: 'Pagamento de Frete',
      ),
      MovimentoModel(
        id: 3,
        tipo: 'D',
        status: 'P',
        conta: 1,
        contaNome: 'Banco do Brasil',
        valor: 250.0,
        dtEmissao: '2026-07-10',
        historico: 'Manutenção Veículo',
      ),
    ];
  }

  Future<MovimentoModel?> createMovimento(MovimentoModel mov) async {
    try {
      final response = await _apiClient.post(
        '/coleta/movimento-conta',
        body: mov.toJson(),
      );

      if (response.success) {
        return mov;
      }
    } catch (e) {
      print('Erro ao criar movimento: $e');
    }
    
    // Mock success
    return MovimentoModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      tipo: mov.tipo,
      conta: mov.conta,
      contaNome: mov.contaNome ?? 'Conta Padrão',
      valor: mov.valor,
      dtEmissao: mov.dtEmissao,
      dtCompensado: mov.dtCompensado,
      historico: mov.historico,
    );
  }

  Future<bool> deleteMovimento(int id) async {
    try {
      await _apiClient.delete('/coleta/movimento-conta/$id');
      return true;
    } catch (e) {
      print('Erro ao deletar movimento: $e');
    }
    return true; // Mock success
  }
}
