import 'package:latlong2/latlong.dart';

class Estado {
  const Estado({
    required this.sigla,
    required this.nome,
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final String sigla;
  final String nome;
  final double latitude;
  final double longitude;
  final double zoom;

  LatLng get center => LatLng(latitude, longitude);
}

abstract final class Nordeste {
  static const defaultUf = 'PB';
  static const overviewLatitude = -8.4;
  static const overviewLongitude = -38.6;
  static const overviewZoom = 4.4;

  static LatLng get overviewCenter =>
      const LatLng(overviewLatitude, overviewLongitude);

  static const estados = <Estado>[
    Estado(sigla: 'AL', nome: 'Alagoas', latitude: -9.62, longitude: -36.63, zoom: 6.9),
    Estado(sigla: 'BA', nome: 'Bahia', latitude: -12.6, longitude: -41.7, zoom: 5.3),
    Estado(sigla: 'CE', nome: 'Ceará', latitude: -5.5, longitude: -39.6, zoom: 6.1),
    Estado(sigla: 'MA', nome: 'Maranhão', latitude: -5.0, longitude: -45.3, zoom: 5.5),
    Estado(sigla: 'PB', nome: 'Paraíba', latitude: -7.15, longitude: -36.7, zoom: 6.9),
    Estado(sigla: 'PE', nome: 'Pernambuco', latitude: -8.3, longitude: -37.9, zoom: 6.6),
    Estado(sigla: 'PI', nome: 'Piauí', latitude: -7.4, longitude: -42.7, zoom: 5.7),
    Estado(sigla: 'RN', nome: 'Rio Grande do Norte', latitude: -5.8, longitude: -36.6, zoom: 7.0),
    Estado(sigla: 'SE', nome: 'Sergipe', latitude: -10.6, longitude: -37.4, zoom: 7.4),
  ];

  static Estado bySigla(String sigla) {
    final upper = sigla.toUpperCase();
    return estados.firstWhere(
      (estado) => estado.sigla == upper,
      orElse: () => estados.firstWhere((e) => e.sigla == defaultUf),
    );
  }
}
