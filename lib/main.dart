import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/record_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SonohalerLabApp());
}

class SonohalerLabApp extends StatelessWidget {
  const SonohalerLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonohaler Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
          surface: const Color(0xFF152535),
          background: const Color(0xFF0D1F2D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1F2D),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const _PermissionGate(),
    );
  }
}

class _PermissionGate extends StatefulWidget {
  const _PermissionGate();

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request microphone and storage permissions
    final statuses = await [
      Permission.microphone,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    final micGranted =
        statuses[Permission.microphone] == PermissionStatus.granted;

    setState(() {
      _granted = micGranted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1F2D),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 20),
              Text('Requesting permissions…',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (!_granted) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1F2D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_off_rounded,
                    size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Microphone Permission Required',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sonohaler Lab needs microphone access to record raw acoustic data. Please grant it in your device Settings.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    await _requestPermissions();
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    RecordScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F2D),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0D1F2D),
        indicatorColor: Colors.tealAccent.withOpacity(0.18),
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded, color: Colors.white54),
            selectedIcon:
                Icon(Icons.mic_rounded, color: Colors.tealAccent),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows_outlined, color: Colors.white54),
            selectedIcon:
                Icon(Icons.table_rows_rounded, color: Colors.tealAccent),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
