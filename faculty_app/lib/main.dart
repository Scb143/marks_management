import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jlsofhoumjlwmrlkmxps.supabase.co',
    anonKey: 'sb_publishable_yE1ylrZ5DcNoEY5Or2myMw__6vMaFKD',
  );

  runApp(const FacultyPortalApp());
}

final supabase = Supabase.instance.client;

class FacultyPortalApp extends StatelessWidget {
  const FacultyPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTIET Faculty Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Transparent scaffold backgrounds ensure the underlying global watermark shows through
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B2356)),
      ),
      // Injects the watermark behind every route/screen automatically
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        final double dynamicWatermarkSize =
            math.min(screenSize.width, screenSize.height) * 0.75;

        return Scaffold(
          backgroundColor: const Color(0xFFEEF2F8),
          body: Stack(
            children: [
              // Centralized, non-interactive responsive watermark
              Positioned.fill(
                child: Center(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.07,
                      child: Image.asset(
                        'assets/mitet.png',
                        width: dynamicWatermarkSize,
                        height: dynamicWatermarkSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
              // Screen content renders directly above the watermark
              if (child != null) child,
            ],
          ),
        );
      },
      home: const FacultyLoginScreen(),
    );
  }
}