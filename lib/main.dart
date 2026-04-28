import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/marketplace_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(MiniGarageApp());
}

class MiniGarageApp extends StatelessWidget {
  const MiniGarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MiniGarage",
      debugShowCheckedModeBanner : false,
      theme: ThemeData.dark(),
      home: MarketplaceScreen(),
    );
  }
}

// FIX FOR WEB: Put this in your main.dart to enable mouse-drag scrolling
class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}