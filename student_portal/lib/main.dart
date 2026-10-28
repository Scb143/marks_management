import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jlsofhoumjlwmrlkmxps.supabase.co',
    anonKey: 'sb_publishable_yE1ylrZ5DcNoEY5Or2myMw__6vMaFKD', // Paste your public anon key here
  );

  runApp(const MyApp());
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTIET Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEEF2F8),
        fontFamily: 'Segoe UI',
      ),
      home: const LoginScreen(),
    );
  }
}