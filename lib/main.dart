import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/core.dart';
import 'screens/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with auto-generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Lock to portrait mode for phone-first design.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use edge-to-edge rendering (status bar overlays content).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor           : Colors.transparent,
      statusBarIconBrightness  : Brightness.dark,
      systemNavigationBarColor : Colors.white,
    ),
  );

  runApp(const CassiaBakeryApp());
}

/// Root widget – sets up Material 3 theme and initial route.
class CassiaBakeryApp extends StatelessWidget {
  const CassiaBakeryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title         : 'Cassia Bakery ERP',
      debugShowCheckedModeBanner: false,
      theme         : AppTheme.light,
      home          : const HomePage(),
    );
  }
}
