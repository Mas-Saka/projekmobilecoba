class Shelter {
  const Shelter(
      {required this.name,
      required this.latitude,
      required this.longitude,
      this.note = 'Titik demo'});
  final String name;
  final double latitude;
  final double longitude;
  final String note;
}

class DisasterReport {
  const DisasterReport(
      {required this.id,
      required this.type,
      required this.description,
      required this.latitude,
      required this.longitude,
      required this.createdAt,
      required this.hash,
      this.status = 'Menunggu verifikasi'});
  final String id;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String hash;
  final String status;

  factory DisasterReport.fromMap(String id, Map<String, dynamic> map) =>
      DisasterReport(
          id: id,
          type: map['type'] as String? ?? 'Lainnya',
          description: map['description'] as String? ?? '',
          latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now(),
          hash: map['hash'] as String? ?? '',
          status: map['status'] as String? ?? 'Menunggu verifikasi');
}
