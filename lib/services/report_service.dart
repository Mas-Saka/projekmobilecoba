import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/app_models.dart';

class ReportService {
  ReportService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  String createHash(
      {required DateTime timestamp,
      required double latitude,
      required double longitude,
      required String type,
      required String description}) {
    final canonical =
        '${timestamp.toUtc().toIso8601String()}|${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}|$type|${description.trim()}';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Stream<List<DisasterReport>> watchReports() => _db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DisasterReport.fromMap(doc.id, doc.data()))
          .toList());

  Future<void> submit(
      {required String type,
      required String description,
      required double latitude,
      required double longitude,
      required String userId}) async {
    final now = DateTime.now().toUtc();
    final hash = createHash(
        timestamp: now,
        latitude: latitude,
        longitude: longitude,
        type: type,
        description: description);
    await _db.collection('reports').add({
      'type': type,
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': now.toIso8601String(),
      'createdAtServer': FieldValue.serverTimestamp(),
      'hash': hash,
      'status': 'Menunggu verifikasi',
      'userId': userId,
    });
  }
}
