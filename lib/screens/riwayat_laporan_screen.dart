import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';
import '../services/report_service.dart';
import '../widgets/resq_widgets.dart';

class RiwayatLaporanScreen extends StatefulWidget {
  const RiwayatLaporanScreen({super.key});

  @override
  State<RiwayatLaporanScreen> createState() => _RiwayatLaporanScreenState();
}

class _RiwayatLaporanScreenState extends State<RiwayatLaporanScreen> {
  final ReportService _service = ReportService();

  bool _isAdmin = false;
  final Set<String> _updatingReports = {};
  List<Map<String, dynamic>> _officers = [];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadOfficers();
  }

  Future<void> _assignOfficer(DisasterReport report) async {
    if (!_isAdmin || _officers.isEmpty) {
      _snack('Belum ada akun petugas yang tersedia.');
      return;
    }

    String? selectedOfficer = _officers.first['user_id'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tugaskan Petugas'),
              content: DropdownButtonFormField<String>(
                value: selectedOfficer,
                decoration: const InputDecoration(
                  labelText: 'Pilih petugas',
                ),
                items: _officers.map((officer) {
                  final id = officer['user_id'] as String;

                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      '${id.substring(0, 8)}...',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedOfficer = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Tugaskan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedOfficer == null) return;

    final reportId = int.tryParse(report.id);
    if (reportId == null) {
      _snack('ID laporan tidak valid.');
      return;
    }

    setState(() => _updatingReports.add(report.id));

    try {
      await Supabase.instance.client.rpc(
        'assign_report_to_officer',
        params: {
          'p_report_id': reportId,
          'p_officer_id': selectedOfficer,
        },
      );

      if (mounted) {
        _snack('Laporan berhasil ditugaskan kepada petugas.');
      }
    } catch (e) {
      debugPrint('Gagal menugaskan petugas: $e');

      if (mounted) {
        _snack(
            'Gagal menugaskan petugas. Periksa status laporan dan hak akses.');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingReports.remove(report.id));
      }
    }
  }

  Future<void> _loadOfficers() async {
    if (!_isAdmin) return;

    try {
      final result = await Supabase.instance.client.rpc(
        'get_petugas_list',
      );

      if (!mounted) return;

      setState(() {
        _officers = List<Map<String, dynamic>>.from(result);
      });
    } catch (e) {
      debugPrint('Gagal memuat daftar petugas: $e');
    }
  }

  Future<void> _checkAdmin() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final result = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final isAdmin = result?['role']?.toString().toLowerCase() == 'admin';

      setState(() {
        _isAdmin = isAdmin;
      });

      if (isAdmin) {
        await _loadOfficers();
      }
    } catch (e) {
      debugPrint('Gagal memeriksa peran admin: $e');
    }
  }

  Future<void> _updateReportStatus(
    DisasterReport report,
    String status,
  ) async {
    if (!_isAdmin) return;

    final reportId = int.tryParse(report.id);

    if (reportId == null) {
      _snack('ID laporan tidak valid.');
      return;
    }

    setState(() => _updatingReports.add(report.id));

    try {
      await Supabase.instance.client.rpc(
        'set_report_status',
        params: {
          'p_report_id': reportId,
          'p_status': status,
        },
      );

      if (mounted) {
        _snack('Status laporan berhasil diubah menjadi $status.');
      }
    } catch (e) {
      debugPrint('Gagal mengubah status laporan: $e');

      if (mounted) {
        _snack('Gagal mengubah status. Periksa hak akses admin.');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingReports.remove(report.id));
      }
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: resqBg,
      appBar: AppBar(
        title: const Text(
          'Riwayat Laporan',
          style: TextStyle(
            color: resqBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: resqBg,
        foregroundColor: resqBlue,
        elevation: 0,
      ),
      body: StreamBuilder<List<DisasterReport>>(
        stream: _service.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ResQCard(
                  child: Text(
                    'Riwayat belum bisa dimuat.\n${snapshot.error}',
                    style: const TextStyle(color: resqRed),
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: resqOrange,
              ),
            );
          }

          final reports = snapshot.data!;

          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ResQCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 44,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada laporan warga.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: resqBlue,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Laporan yang dikirim akan muncul di sini.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Text(
                'LAPORAN WARGA',
                style: TextStyle(
                  color: resqOrange,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${reports.length} laporan terbaru',
                style: const TextStyle(
                  color: resqBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...reports.map((report) {
                final isUpdating = _updatingReports.contains(report.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ResQCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: resqOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.campaign_outlined,
                                color: resqOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.type,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: resqBlue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy • HH:mm',
                                    ).format(report.createdAt.toLocal()),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Deskripsi Bencana',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: resqBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(report.description),
                        if (report.photoPath != null &&
                            report.photoPath!.isNotEmpty)
                          _ReportPhoto(
                            photoPath: report.photoPath,
                          ),
                        if (report.handlingPhotoPath != null &&
                            report.handlingPhotoPath!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Foto Bukti Penanganan Petugas',
                            style: TextStyle(
                              color: resqBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          _ReportPhoto(
                            photoPath: report.handlingPhotoPath,
                          ),
                        ],
                        if (report.handlingNotes != null &&
                            report.handlingNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Catatan Penanganan Petugas',
                            style: TextStyle(
                              color: resqBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(report.handlingNotes!),
                        ],
                        if (report.handlingStatus.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Status Penanganan',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: resqBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final status = report.handlingStatus.trim();
                              final statusLower = status.toLowerCase();

                              final Color statusColor;
                              final Color statusBackground;

                              if (statusLower == 'selesai') {
                                statusColor = const Color(0xFF2E7D32);
                                statusBackground = const Color(0xFFE8F5E9);
                              } else if (statusLower.contains('proses') ||
                                  statusLower.contains('ditangani')) {
                                statusColor = const Color(0xFFEF6C00);
                                statusBackground = const Color(0xFFFFF3E0);
                              } else {
                                statusColor = Colors.blueGrey;
                                statusBackground = const Color(0xFFECEFF1);
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Lokasi kejadian',
                          style: TextStyle(
                            color: resqBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          'Latitude: ${report.latitude.toStringAsFixed(6)}\n'
                          'Longitude: ${report.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: resqBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            'SHA-256\n${report.hash}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final status = report.status.trim();
                            final statusLower = status.toLowerCase();

                            final Color statusColor;
                            final Color statusBackground;

                            if (statusLower == 'terverifikasi') {
                              statusColor = const Color(0xFF2E7D32);
                              statusBackground = const Color(0xFFE8F5E9);
                            } else if (statusLower == 'ditolak') {
                              statusColor = const Color(0xFFC62828);
                              statusBackground = const Color(0xFFFFEBEE);
                            } else {
                              statusColor = const Color(0xFFEF6C00);
                              statusBackground = const Color(0xFFFFF3E0);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Laporan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: resqBlue,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBackground,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Panel verifikasi admin',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: resqBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final status in [
                                'Terverifikasi',
                                'Belum terkonfirmasi',
                                'Ditolak',
                              ])
                                OutlinedButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () => _updateReportStatus(
                                            report,
                                            status,
                                          ),
                                  child: Text(status),
                                ),
                            ],
                          ),
                          if (report.status == 'Terverifikasi') ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isUpdating
                                    ? null
                                    : () => _assignOfficer(report),
                                child: const Text('Tugaskan Petugas'),
                              ),
                            ),
                          ],
                          if (isUpdating)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ReportPhoto extends StatefulWidget {
  const _ReportPhoto({required this.photoPath});

  final String? photoPath;

  @override
  State<_ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<_ReportPhoto> {
  late Future<String?> _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ReportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photoPath != widget.photoPath) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _photoUrl = ReportService().getReportPhotoUrl(widget.photoPath);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoPath == null || widget.photoPath!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _photoUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Foto bukti gagal dimuat.'),
          );
        }
        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Foto bukti tidak dapat dimuat.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('Gagal menampilkan foto bukti.'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
