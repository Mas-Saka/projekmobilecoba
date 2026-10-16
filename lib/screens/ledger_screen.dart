import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import '../services/report_service.dart';
import '../widgets/resq_widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

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

        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return const Text('Foto bukti tidak dapat dimuat.');
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
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedPhoto;
  Uint8List? _photoBytes;

  bool _pickingPhoto = false;

  LatLng _selectedLocation = const LatLng(
    -7.7971,
    110.3705,
  );

  bool _gettingLocation = false;

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

  void _selectLocation(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _lat.text = point.latitude.toStringAsFixed(6);
      _lon.text = point.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          _snack('Aktifkan layanan lokasi GPS terlebih dahulu.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _snack('Izin lokasi belum diberikan.');
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _snack(
            'Izin lokasi ditolak permanen. '
            'Aktifkan melalui pengaturan aplikasi.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      final point = LatLng(
        position.latitude,
        position.longitude,
      );

      _selectLocation(point);

      _mapController.move(point, 16);

      if (mounted) {
        _snack('Lokasi GPS berhasil dipilih.');
      }
    } catch (e) {
      debugPrint('Gagal mengambil GPS: $e');

      if (mounted) {
        _snack('Gagal mengambil lokasi GPS. Coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      setState(() => _pickingPhoto = true);

      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (photo == null) return;

      final extension = photo.name.contains('.')
          ? photo.name.split('.').last.toLowerCase()
          : '';

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        if (mounted) {
          _snack('Format foto harus JPG, JPEG, PNG, atau WebP.');
        }
        return;
      }

      final bytes = await photo.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          _snack('Foto tidak dapat dibaca. Silakan pilih foto lain.');
        }
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          _snack('Ukuran foto maksimal 5 MB. Pilih foto yang lebih kecil.');
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedPhoto = photo;
        _photoBytes = bytes;
      });
    } catch (e) {
      debugPrint('Gagal memilih foto: $e');

      if (mounted) {
        _snack('Gagal mengambil foto. Periksa izin kamera atau galeri.');
      }
    } finally {
      if (mounted) {
        setState(() => _pickingPhoto = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPhoto == null || _photoBytes == null) {
      _snack('Foto bukti wajib dipilih sebelum mengirim laporan.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _snack('Silakan masuk terlebih dahulu.');
      return;
    }

    setState(() => _busy = true);

    String? uploadedPhotoPath;

    try {
      final extension = _selectedPhoto!.name.contains('.')
          ? _selectedPhoto!.name.split('.').last.toLowerCase()
          : '';

      uploadedPhotoPath = await _service.uploadReportPhoto(
        userId: user.id,
        bytes: _photoBytes!,
        extension: extension,
      );

      await _service.submit(
        type: _type,
        description: _description.text,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        userId: user.id,
        photoPath: uploadedPhotoPath,
      );

      if (!mounted) return;

      setState(() {
        _selectedPhoto = null;
        _photoBytes = null;
      });

      _description.clear();

      _snack('Laporan beserta foto bukti berhasil dikirim.');
    } catch (e, stackTrace) {
      debugPrint('GAGAL KIRIM LAPORAN: $e');
      debugPrintStack(stackTrace: stackTrace);

      // Hapus foto jika sudah terunggah tetapi laporan gagal disimpan.
      if (uploadedPhotoPath != null) {
        try {
          await _service.deleteReportPhoto(uploadedPhotoPath);
        } catch (deleteError) {
          debugPrint('Gagal membersihkan foto: $deleteError');
        }
      }

      if (mounted) {
        _snack('Gagal mengirim laporan: $e');
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
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto bukti kejadian *',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: resqBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wajib menyertakan foto. Format JPG, PNG, atau WebP, maksimal 5 MB.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_photoBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.memory(
                      _photoBytes!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy || _pickingPhoto
                          ? null
                          : () {
                              setState(() {
                                _selectedPhoto = null;
                                _photoBytes = null;
                              });
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus foto'),
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: resqBg,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: Colors.blueGrey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Belum ada foto bukti',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || _pickingPhoto
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Kamera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || _pickingPhoto
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeri'),
                      ),
                    ),
                  ],
                ),
                if (_pickingPhoto)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lokasi kejadian',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: resqBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 14,
                        onTap: (tapPosition, point) {
                          _selectLocation(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.resq',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 48,
                              height: 48,
                              child: const Icon(
                                Icons.location_pin,
                                color: resqRed,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _gettingLocation ? null : _useCurrentLocation,
                  icon: _gettingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _gettingLocation
                        ? 'Mengambil lokasi...'
                        : 'Gunakan Lokasi Saya',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ketuk peta untuk memilih titik kejadian. '
                  'Kamu tidak harus berada tepat di lokasi bencana.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Latitude: ${_selectedLocation.latitude.toStringAsFixed(6)}\n'
                  'Longitude: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _busy
                      ? 'Mengirim...'
                      : _pickingPhoto
                          ? 'Memproses foto...'
                          : 'Kirim laporan',
                  icon: Icons.near_me_rounded,
                  onPressed: _busy || _pickingPhoto ? null : _submit,
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
                        _ReportPhoto(photoPath: report.photoPath),
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
