import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'File Transfer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

/// Splash screen with initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Request permissions
      setState(() => _statusMessage = 'Requesting permissions...');
      await _requestPermissions();

      // Initialize app provider
      setState(() => _statusMessage = 'Starting services...');
      final provider = context.read<AppProvider>();
      await provider.initialize();

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');

      // Show error dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initialize(); // Retry
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Storage permission (for Android)
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // For Android 13+ (API 33+), use new photo/video/audio permissions
    if (await Permission.photos.isDenied) {
      await Permission.photos.request();
    }

    if (await Permission.videos.isDenied) {
      await Permission.videos.request();
    }

    // Network permissions are automatically granted
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon/logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.swap_horiz,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // App name
            const Text(
              'File Transfer',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Fast & Secure File Sharing',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 16),

            // Status message
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
