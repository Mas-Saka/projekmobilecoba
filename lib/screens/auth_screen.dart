import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/resq_widgets.dart';
import 'main_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Scaffold(
              body:
                  Center(child: CircularProgressIndicator(color: resqOrange)));
        if (snapshot.data != null) return const MainScreen();
        return const AuthScreen();
      });
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(
          () => _error = 'Masukkan email dan kata sandi minimal 6 karakter.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Autentikasi gagal.');
    } catch (_) {
      setState(() => _error =
          'Terjadi kesalahan. Periksa koneksi dan konfigurasi Firebase.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics && !await auth.isDeviceSupported()) {
        setState(
            () => _error = 'Perangkat tidak mendukung autentikasi biometrik.');
        return;
      }
      final ok = await auth.authenticate(
          localizedReason: 'Verifikasi identitas untuk membuka ResQ');
      if (ok && mounted)
        setState(() => _error =
            'Biometrik berhasil diverifikasi. Masuk dengan akun email terlebih dahulu pada prototipe ini.');
    } catch (_) {
      setState(() => _error =
          'Biometrik belum tersedia atau belum diatur pada perangkat.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                                color: resqOrange,
                                borderRadius: BorderRadius.circular(22)),
                            child: const Icon(Icons.health_and_safety_rounded,
                                color: Colors.white, size: 38)),
                        const SizedBox(height: 24),
                        const Text('Tetap siap.\nTetap selamat.',
                            style: TextStyle(
                                fontSize: 32,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: resqBlue)),
                        const SizedBox(height: 10),
                        const Text(
                            'Teman siaga untuk informasi bencana dan persiapan darurat.'),
                        const SizedBox(height: 28),
                        ResQCard(
                            child: Column(children: [
                          Text(
                              _register
                                  ? 'Buat akun ResQ'
                                  : 'Selamat datang kembali',
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: resqBlue)),
                          const SizedBox(height: 18),
                          TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(14))))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                  labelText: 'Kata sandi',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined)),
                                  border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(14))))),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: resqRed))
                          ],
                          const SizedBox(height: 18),
                          PrimaryButton(
                              label: _busy
                                  ? 'Memproses...'
                                  : (_register ? 'Daftar akun' : 'Masuk'),
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _busy ? null : _submit),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: () => setState(() {
                                    _register = !_register;
                                    _error = null;
                                  }),
                              child: Text(_register
                                  ? 'Sudah punya akun? Masuk'
                                  : 'Belum punya akun? Daftar')),
                          OutlinedButton.icon(
                              onPressed: _biometric,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Verifikasi biometrik'),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)))),
                        ])),
                        const SizedBox(height: 16),
                        const Text(
                            'Informasi ResQ membantu persiapan, bukan pengganti petugas darurat.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blueGrey)),
                      ])))));
}
