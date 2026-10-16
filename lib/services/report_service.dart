import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class ReportService {
  ReportService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const String photoBucket = 'report-photos';

  String createHash({
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required String type,
    required String description,
  }) {
    final canonical = '${timestamp.toUtc().toIso8601String()}|'
        '${latitude.toStringAsFixed(6)}|'
        '${longitude.toStringAsFixed(6)}|'
        '$type|${description.trim()}';

    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Stream<List<DisasterReport>> watchReports() {
    return _db
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) {
          return rows.map((row) {
            return DisasterReport.fromMap(
              row['id'].toString(),
              {
                'type': row['type'],
                'description': row['description'],
                'latitude': row['latitude'],
                'longitude': row['longitude'],
                'created_at': row['created_at'],
                'hash': row['hash'],
                'status': row['status'],
                'user_id': row['user_id'],
                'photo_path': row['photo_path'],
              },
            );
          }).toList();
        });
  }

  Future<String> uploadReportPhoto({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll('.', '');

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(safeExtension)) {
      throw Exception('Format foto harus JPG, JPEG, PNG, atau WebP.');
    }

    if (bytes.isEmpty) {
      throw Exception('File foto kosong.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Ukuran foto maksimal 5 MB.');
    }

    final fileName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$safeExtension';

    final path = '$userId/$fileName';

    await _db.storage.from(photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: switch (safeExtension) {
              'jpg' || 'jpeg' => 'image/jpeg',
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'application/octet-stream',
            },
            upsert: false,
          ),
        );

    return path;
  }

  Future<String?> getReportPhotoUrl(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) {
      debugPrint('FOTO ERROR: photoPath kosong atau null.');
      return null;
    }

    try {
      final url =
          await _db.storage.from(photoBucket).createSignedUrl(photoPath, 3600);

      debugPrint('FOTO BERHASIL: $photoPath');
      return url;
    } catch (e, stackTrace) {
      debugPrint('FOTO ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> deleteReportPhoto(String path) async {
    await _db.storage.from(photoBucket).remove([path]);
  }

  Future<void> submit({
    required String type,
    required String description,
    required double latitude,
    required double longitude,
    required String userId,
    required String photoPath,
  }) async {
    final now = DateTime.now().toUtc();

    final hash = createHash(
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      type: type,
      description: description,
    );

    await _db.from('reports').insert({
      'type': type,
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'hash': hash,
      'status': 'Menunggu verifikasi',
      'user_id': userId,
      'photo_path': photoPath,
    });
  }
}
