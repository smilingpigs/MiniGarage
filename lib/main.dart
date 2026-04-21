import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/marketplace_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://enkvxapxitmrobljrjik.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVua3Z4YXB4aXRtcm9ibGpyamlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjE1MTgsImV4cCI6MjA5MTAzNzUxOH0.zvlFKG0yK_gF7UXpVdetKlzkD3RDgy9jbe-r6xPr3ag',
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