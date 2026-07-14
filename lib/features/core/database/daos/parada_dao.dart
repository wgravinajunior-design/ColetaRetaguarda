import '../base_dao.dart';
import '../../../coleta/models/parada_model.dart';

class ParadaDao extends BaseDao<ParadaModel> {
  @override
  String get tableName => 'tb_parada';

  @override
  ParadaModel fromMap(Map<String, dynamic> map) {
    return ParadaModel(
      id: map['id'] as int?,
      rotaId: map['rota_id'] as int?,
      pessoaId: map['pessoa_id'] as int?,
      pessoaNome: (map['pessoa_nome'] as String?) ?? '',
      cnpjCpf: (map['cnpj_cpf'] as String?) ?? '',
      endereco: (map['endereco'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as String?) ?? 'P',
      temperatura: (map['temperatura'] as num?)?.toDouble(),
      volume: (map['volume'] as num?)?.toDouble(),
      justificativa: map['justificativa'] as String?,
      gpsCapturaLatitude: (map['gps_captura_latitude'] as num?)?.toDouble(),
      gpsCapturaltitude: (map['gps_captura_longitude'] as num?)?.toDouble(),
      horarioChegada: map['horario_chegada'] as String?,
      horarioSaida: map['horario_saida'] as String?,
      assinaturaBase64: map['assinatura_base64'] as String?,
      fotoPath: map['foto_path'] as String?,
      dataCadastro: map['data_cadastro'] != null
          ? DateTime.tryParse(map['data_cadastro'] as String)
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap(ParadaModel obj) {
    return {
      'id': obj.id,
      'rota_id': obj.rotaId,
      'pessoa_id': obj.pessoaId,
      'pessoa_nome': obj.pessoaNome,
      'cnpj_cpf': obj.cnpjCpf,
      'endereco': obj.endereco,
      'latitude': obj.latitude,
      'longitude': obj.longitude,
      'status': obj.status,
      'temperatura': obj.temperatura,
      'volume': obj.volume,
      'justificativa': obj.justificativa,
      'gps_captura_latitude': obj.gpsCapturaLatitude,
      'gps_captura_longitude': obj.gpsCapturaltitude,
      'horario_chegada': obj.horarioChegada,
      'horario_saida': obj.horarioSaida,
      'assinatura_base64': obj.assinaturaBase64,
      'foto_path': obj.fotoPath,
      'data_cadastro': obj.dataCadastro?.toIso8601String(),
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
  }

  Future<List<ParadaModel>> getByRotaId(int rotaId) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'rota_id = ?',
      whereArgs: [rotaId],
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<ParadaModel>> getByStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [status],
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<int> updateStatus(
    int paradaId,
    String newStatus, {
    double? temperatura,
    double? volume,
    String? justificativa,
    String? assinaturaBase64,
    String? fotoPath,
  }) async {
    final db = await database;
    final map = <String, dynamic>{
      'status': newStatus,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
    if (temperatura != null) map['temperatura'] = temperatura as dynamic;
    if (volume != null) map['volume'] = volume as dynamic;
    if (justificativa != null) map['justificativa'] = justificativa;
    if (assinaturaBase64 != null) map['assinatura_base64'] = assinaturaBase64;
    if (fotoPath != null) map['foto_path'] = fotoPath;

    return db.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [paradaId],
    );
  }

  Future<int> registrarGPS(
    int paradaId,
    double latitude,
    double longitude, {
    String? horarioChegada,
  }) async {
    final db = await database;
    final map = <String, dynamic>{
      'gps_captura_latitude': latitude,
      'gps_captura_longitude': longitude,
      'data_atualizacao': DateTime.now().toIso8601String(),
    };
    if (horarioChegada != null) map['horario_chegada'] = horarioChegada;

    return db.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [paradaId],
    );
  }
}
