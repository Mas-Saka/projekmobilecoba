import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';

class ReportService {
  ReportService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

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
                'createdAt': row['created_at'],
                'hash': row['hash'],
                'status': row['status'],
                'userId': row['user_id'],
              },
            );
          }).toList();
        });
  }

  Future<void> submit({
    required String type,
    required String description,
    required double latitude,
    required double longitude,
    required String userId,
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
    });
  }
}
