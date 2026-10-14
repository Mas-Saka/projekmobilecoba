import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import '../services/report_service.dart';
import '../widgets/resq_widgets.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _lat = TextEditingController(text: '-7.7971');
  final _lon = TextEditingController(text: '110.3705');
  final _service = ReportService();

  String _type = 'Banjir';
  bool _busy = false;
  bool _isAdmin = false;
  final Set<String> _updatingReports = {};

  @override
  void dispose() {
    _description.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
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

      setState(() {
        _isAdmin = result?['role'] == 'admin';
      });
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

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _snack('Silakan masuk terlebih dahulu.');
      return;
    }

    setState(() => _busy = true);

    try {
      await _service.submit(
        type: _type,
        description: _description.text,
        latitude: double.parse(_lat.text),
        longitude: double.parse(_lon.text),
        userId: user.id,
      );

      _description.clear();

      if (mounted) {
        _snack('Laporan berhasil dikirim.');
      }
    } catch (e) {
      if (mounted) {
        _snack(
          'Gagal mengirim laporan. Periksa koneksi dan aturan Supabase.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String? _validateCoord(
    String? value,
    double min,
    double max,
  ) {
    final number = double.tryParse(value ?? '');

    if (number == null) {
      return 'Angka tidak valid';
    }

    if (number < min || number > max) {
      return 'Rentang $min s.d. $max';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text(
          'LEDGER / WARGA',
          style: TextStyle(
            color: resqOrange,
            letterSpacing: 1.5,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Saling jaga, saling kabari.',
          style: TextStyle(
            color: resqBlue,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(
          'Lapor kondisi sekitar',
          subtitle:
              'Gunakan koordinat perkiraan yang benar dan tulis informasi faktual.',
        ),
        const SizedBox(height: 10),
        ResQCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kejadian',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(13),
                      ),
                    ),
                  ),
                  items: const [
                    'Banjir',
                    'Tanah longsor',
                    'Gempa',
                    'Kebakaran',
                    'Jalan terputus',
                    'Lainnya',
                  ].map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _type = value ?? 'Banjir';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi laporan',
                    hintText: 'Contoh: air mulai naik di jalan...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(13),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 8) {
                      return 'Deskripsi minimal 8 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(13),
                            ),
                          ),
                        ),
                        validator: (value) => _validateCoord(value, -90, 90),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lon,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(13),
                            ),
                          ),
                        ),
                        validator: (value) => _validateCoord(value, -180, 180),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Koordinat awal adalah contoh Yogyakarta. '
                  'Ganti sesuai lokasi kejadian.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _busy ? 'Mengirim...' : 'Kirim laporan',
                  icon: Icons.near_me_rounded,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle(
          'Ledger laporan',
          subtitle: 'Fingerprint SHA-256 membantu memeriksa perubahan data, '
              'bukan memverifikasi kebenaran laporan.',
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<DisasterReport>>(
          stream: _service.watchReports(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ResQCard(
                child: Text(
                  'Laporan belum bisa dimuat. '
                  'Pastikan Supabase sudah aktif.\n${snapshot.error}',
                  style: const TextStyle(color: resqRed),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const ResQCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: resqOrange,
                    ),
                  ),
                ),
              );
            }

            final reports = snapshot.data!;

            if (reports.isEmpty) {
              return const ResQCard(
                child: Text('Belum ada laporan warga.'),
              );
            }

            return Column(
              children: reports.map((report) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy • HH:mm',
                                    ).format(
                                      report.createdAt.toLocal(),
                                    ),
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
                        const SizedBox(height: 10),
                        Text(report.description),
                        const SizedBox(height: 8),
                        Text(
                          '${report.latitude.toStringAsFixed(5)}, '
                          '${report.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 7),
                        Text(
                          'Status: ${report.status}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: resqOrange,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 10),
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
                                  onPressed: _updatingReports
                                          .contains(report.id)
                                      ? null
                                      : () =>
                                          _updateReportStatus(report, status),
                                  child: Text(status),
                                ),
                            ],
                          ),
                          if (_updatingReports.contains(report.id))
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Alat cepat'),
        const SizedBox(height: 10),
        const _ToolsCard(),
      ],
    );
  }
}

class _ToolsCard extends StatefulWidget {
  const _ToolsCard();

  @override
  State<_ToolsCard> createState() => _ToolsCardState();
}

class _ToolsCardState extends State<_ToolsCard> {
  String _zone = 'WIB';
  double _amount = 1;
  String _currency = 'USD';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final offset = {
      'WIB': 7,
      'WITA': 8,
      'WIT': 9,
      'UTC': 0,
    }[_zone]!;

    final local = now.add(Duration(hours: offset));

    final rate = _currency == 'USD'
        ? 15500.0
        : _currency == 'EUR'
            ? 16900.0
            : 1.0;

    final rupiah = _currency == 'IDR' ? _amount : _amount * rate;

    return ResQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Konverter zona waktu',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: resqBlue,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _zone,
            items: const ['WIB', 'WITA', 'WIT', 'UTC'].map((zone) {
              return DropdownMenuItem(
                value: zone,
                child: Text(zone),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _zone = value ?? 'WIB';
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd MMM yyyy • HH:mm').format(local),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Konverter mata uang (kurs demo)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: resqBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '1',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _amount = double.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  items: const ['USD', 'EUR', 'IDR'].map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _currency = value ?? 'USD';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Mata uang',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '≈ Rp${rupiah.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: resqOrange,
            ),
          ),
          const Text(
            'Kurs ilustrasi, bukan kurs real-time.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }
}
