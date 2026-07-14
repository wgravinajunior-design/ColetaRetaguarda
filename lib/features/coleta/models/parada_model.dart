class ParadaModel {
  int? id;
  int? rotaId;
  int? pessoaId;
  String pessoaNome;
  String cnpjCpf;
  String endereco;
  double latitude;
  double longitude;
  String status; // P=Pendente, E=Em Andamento, C=Sucesso, R=Recusado
  double? temperatura;
  double? volume;
  String? justificativa;
  double? gpsCapturaLatitude;
  double? gpsCapturaltitude;
  String? horarioChegada;
  String? horarioSaida;
  DateTime? dataCadastro;

  ParadaModel({
    this.id,
    this.rotaId,
    this.pessoaId,
    required this.pessoaNome,
    required this.cnpjCpf,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    this.status = 'P',
    this.temperatura,
    this.volume,
    this.justificativa,
    this.gpsCapturaLatitude,
    this.gpsCapturaltitude,
    this.horarioChegada,
    this.horarioSaida,
    this.dataCadastro,
  });

  factory ParadaModel.fromJson(Map<String, dynamic> json) {
    return ParadaModel(
      id: json['id'] as int?,
      rotaId: json['rota_id'] as int?,
      pessoaId: json['pessoa_id'] as int?,
      pessoaNome: json['pessoa_nome'] as String? ?? '',
      cnpjCpf: json['cnpj_cpf'] as String? ?? '',
      endereco: json['endereco'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'P',
      temperatura: (json['temperatura'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      justificativa: json['justificativa'] as String?,
      gpsCapturaLatitude: (json['gps_captura_latitude'] as num?)?.toDouble(),
      gpsCapturaltitude: (json['gps_captura_longitude'] as num?)?.toDouble(),
      horarioChegada: json['horario_chegada'] as String?,
      horarioSaida: json['horario_saida'] as String?,
      dataCadastro: json['data_cadastro'] != null
          ? DateTime.tryParse(json['data_cadastro'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rota_id': rotaId,
      'pessoa_id': pessoaId,
      'pessoa_nome': pessoaNome,
      'cnpj_cpf': cnpjCpf,
      'endereco': endereco,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'temperatura': temperatura,
      'volume': volume,
      'justificativa': justificativa,
      'gps_captura_latitude': gpsCapturaLatitude,
      'gps_captura_longitude': gpsCapturaltitude,
      'horario_chegada': horarioChegada,
      'horario_saida': horarioSaida,
      'data_cadastro': dataCadastro?.toIso8601String(),
    };
  }

  ParadaModel copyWith({
    int? id,
    int? rotaId,
    int? pessoaId,
    String? pessoaNome,
    String? cnpjCpf,
    String? endereco,
    double? latitude,
    double? longitude,
    String? status,
    double? temperatura,
    double? volume,
    String? justificativa,
    double? gpsCapturaLatitude,
    double? gpsCapturaltitude,
    String? horarioChegada,
    String? horarioSaida,
    DateTime? dataCadastro,
  }) {
    return ParadaModel(
      id: id ?? this.id,
      rotaId: rotaId ?? this.rotaId,
      pessoaId: pessoaId ?? this.pessoaId,
      pessoaNome: pessoaNome ?? this.pessoaNome,
      cnpjCpf: cnpjCpf ?? this.cnpjCpf,
      endereco: endereco ?? this.endereco,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      temperatura: temperatura ?? this.temperatura,
      volume: volume ?? this.volume,
      justificativa: justificativa ?? this.justificativa,
      gpsCapturaLatitude: gpsCapturaLatitude ?? this.gpsCapturaLatitude,
      gpsCapturaltitude: gpsCapturaltitude ?? this.gpsCapturaltitude,
      horarioChegada: horarioChegada ?? this.horarioChegada,
      horarioSaida: horarioSaida ?? this.horarioSaida,
      dataCadastro: dataCadastro ?? this.dataCadastro,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'P':
        return 'Pendente';
      case 'E':
        return 'Em Andamento';
      case 'C':
        return 'Sucesso';
      case 'R':
        return 'Recusado';
      default:
        return 'Desconhecido';
    }
  }

  String get statusEmoji {
    switch (status) {
      case 'P':
        return '🔴';
      case 'E':
        return '🟡';
      case 'C':
        return '🟢';
      case 'R':
        return '⚫';
      default:
        return '⚪';
    }
  }
}
