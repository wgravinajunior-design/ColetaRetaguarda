import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapService {
  static const String openStreetMapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String openStreetMapAttr = '© OpenStreetMap contributors';

  static TileLayer getTileLayer({bool useOnline = true}) {
    return TileLayer(
      urlTemplate: openStreetMapUrl,
      userAgentPackageName: 'com.example.flutter_retaguarda',
      maxZoom: 19,
      // Offline tiles seriam carregadas de asset ou cache aqui
      // Por enquanto, usamos online tiles com cache
    );
  }

  static LatLng paradasListToLatLng(List<Map<String, dynamic>> paradas) {
    if (paradas.isEmpty) {
      return const LatLng(-19.8157, -43.9542); // Belo Horizonte como padrão
    }

    double latSum = 0, lngSum = 0;
    for (var p in paradas) {
      latSum += p['latitude'] as double;
      lngSum += p['longitude'] as double;
    }

    return LatLng(latSum / paradas.length, lngSum / paradas.length);
  }

  static List<LatLng> paradasToPolyline(List<Map<String, dynamic>> paradas) {
    return paradas
        .map((p) => LatLng(p['latitude'] as double, p['longitude'] as double))
        .toList();
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'P':
        return Colors.red;
      case 'E':
        return Colors.orange;
      case 'C':
        return Colors.green;
      case 'R':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  static String getStatusEmoji(String status) {
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
