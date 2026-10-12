import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/local_service.dart';
import '../widgets/resq_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _local = LocalService();
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _contact = TextEditingController();
  final _feedback = TextEditingController();
  bool _loading = true, _saving = false, _unlocked = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _blood.dispose();
    _allergies.dispose();
    _contact.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _local.loadMedical();
    if (!mounted) return;
    _blood.text = data['blood'] ?? '';
    _allergies.text = data['allergies'] ?? '';
    _contact.text = data['contact'] ?? '';
    setState(() {
      _loading = false;
      _unlocked = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _local.saveMedical({
        'blood': _blood.text.trim(),
        'allergies': _allergies.text.trim(),
        'contact': _contact.text.trim()
      });
      if (mounted) _snack('Data medis tersimpan di perangkat.');
    } catch (_) {
      if (mounted) _snack('Gagal menyimpan data.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _biometricLock() async {
    try {
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      if (!supported) {
        _snack('Perangkat tidak mendukung biometrik.');
        return;
      }
      final ok =
          await auth.authenticate(localizedReason: 'Buka data medis ResQ');
      if (mounted) setState(() => _unlocked = ok);
    } catch (_) {
      _snack('Biometrik tidak tersedia.');
    }
  }

  void _snack(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text('PROFIL / PERSONAL',
              style: TextStyle(
                  color: resqOrange,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Informasi pentingmu.',
              style: TextStyle(
                  color: resqBlue, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          ResQCard(
              child: Row(children: [
            Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                    color: resqBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.person_rounded,
                    size: 32, color: resqBlue)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user?.email ?? 'Pengguna ResQ',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: resqBlue)),
                  const SizedBox(height: 4),
                  const Text('Akun ResQ • Data medis lokal',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12))
                ]))
          ])),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
                child: SectionTitle('Rekam medis darurat',
                    subtitle: 'Disimpan lokal pada perangkat ini.')),
            IconButton(
                onPressed: _biometricLock,
                icon:
                    const Icon(Icons.fingerprint, color: resqOrange, size: 30))
          ]),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: resqOrange))
          else if (!_unlocked)
            ResQCard(
                child: Column(children: [
              const Icon(Icons.lock_outline, size: 38, color: resqBlue),
              const SizedBox(height: 8),
              const Text('Data medis terkunci'),
              const SizedBox(height: 8),
              PrimaryButton(
                  label: 'Buka dengan biometrik',
                  icon: Icons.fingerprint,
                  onPressed: _biometricLock)
            ]))
          else
            ResQCard(
                child: Column(children: [
              DropdownButtonFormField<String>(
                  value: _blood.text.isEmpty ? null : _blood.text,
                  decoration: const InputDecoration(
                      labelText: 'Golongan darah',
                      border: OutlineInputBorder()),
                  items: const [
                    'A+',
                    'A-',
                    'B+',
                    'B-',
                    'AB+',
                    'AB-',
                    'O+',
                    'O-',
                    'Belum tahu'
                  ]
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _blood.text = v ?? ''),
                  hint: const Text('Pilih golongan darah')),
              const SizedBox(height: 12),
              TextField(
                  controller: _allergies,
                  decoration: const InputDecoration(
                      labelText: 'Alergi / kondisi penting',
                      hintText: 'Contoh: alergi obat tertentu',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Kontak darurat',
                      hintText: 'Nomor keluarga / wali',
                      border: OutlineInputBorder())),
              const SizedBox(height: 14),
              PrimaryButton(
                  label: _saving ? 'Menyimpan...' : 'Simpan data medis',
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save),
              const SizedBox(height: 8),
              TextButton.icon(
                  onPressed: () => setState(() => _unlocked = false),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Kunci data medis'))
            ])),
          const SizedBox(height: 24),
          const SectionTitle('Masukan untuk ResQ'),
          const SizedBox(height: 10),
          ResQCard(
              child: Column(children: [
            TextField(
                controller: _feedback,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Kritik, saran, atau ide',
                    border: OutlineInputBorder(),
                    hintText: 'Apa yang bisa kami perbaiki?')),
            const SizedBox(height: 12),
            PrimaryButton(
                label: 'Kirim masukan',
                icon: Icons.chat_bubble_outline,
                onPressed: () {
                  if (_feedback.text.trim().isEmpty) {
                    _snack('Tulis masukan terlebih dahulu.');
                    return;
                  }
                  _snack(
                      'Terima kasih! Form feedback demo belum mengirim ke server.');
                  _feedback.clear();
                })
          ])),
          const SizedBox(height: 24),
          SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AppProvider>().signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar dari akun'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: resqRed,
                      side: const BorderSide(color: resqRed),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))))),
          const SizedBox(height: 14),
          const Text(
              'ResQ adalah prototipe edukasi. Simpan informasi medis dengan bijak dan jangan mengandalkan aplikasi ini sebagai satu-satunya sarana darurat.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.4)),
        ]);
  }
}
