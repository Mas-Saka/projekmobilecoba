import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/sensor_engine.dart';
import '../widgets/resq_widgets.dart';
import 'home_screen.dart';
import 'survival_screen.dart';
import 'ledger_screen.dart';
import 'news_screen.dart';
import 'profile_screen.dart';
import 'riwayat_laporan_screen.dart';
import 'tugas_petugas_screen.dart';
import 'admin/kelola_berita_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final SensorEngine _sensor;

  Future<void> _loadRole() async {
    await context.read<AppProvider>().loadUserRole();
  }

  @override
  void initState() {
    super.initState();

    _sensor = SensorEngine(
      onEmergency: () {
        if (mounted) {
          context.read<AppProvider>().triggerEmergency();
        }
      },
    );

    context.read<AppProvider>().attachSensor(_sensor);
    _loadRole();
  }

  @override
  void dispose() {
    _sensor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (app.roleLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    late final List<Widget> screens;
    late final List<NavigationDestination> destinations;

    if (app.userRole == 'admin') {
      screens = const [
        HomeScreen(),
        RiwayatLaporanScreen(),
        KelolaBeritaScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Verifikasi',
        ),
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper),
          label: 'Berita',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    } else if (app.userRole == 'petugas') {
      screens = const [
        HomeScreen(),
        TugasPetugasScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Tugas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    } else {
      screens = const [
        HomeScreen(),
        SurvivalScreen(),
        LedgerScreen(),
        NewsScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.radar_outlined),
          selectedIcon: Icon(Icons.radar),
          label: 'Siaga',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent),
          label: 'AI Hub',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Laporan',
        ),
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper),
          label: 'Berita',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }

    final safeIndex = app.tabIndex.clamp(0, screens.length - 1);

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: safeIndex,
              children: screens,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: app.setTab,
            backgroundColor: Colors.white,
            indicatorColor: resqOrange.withValues(alpha: .13),
            destinations: destinations,
          ),
        ),
        if (app.emergencyActive)
          EmergencyOverlay(onCancel: app.cancelEmergency),
      ],
    );
  }
}

class EmergencyOverlay extends StatefulWidget {
  const EmergencyOverlay({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay> {
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: resqRed,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 88,
                ),
                const SizedBox(height: 18),
                const Text(
                  'KONDISI DARURAT?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deteksi sensor mengindikasikan benturan dan kondisi gelap. Pastikan kamu aman.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '$_seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 68,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'detik sebelum alarm lokal',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Saya aman — batalkan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: resqRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (_seconds == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'Hitung mundur selesai. Ini prototipe; alarm otomatis belum menghubungi layanan darurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
