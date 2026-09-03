import 'package:flutter/material.dart';
import 'screens/demo_welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RtTrainerApp());
}

class RtTrainerApp extends StatelessWidget {
  const RtTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RT Trainer Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DemoWelcomeScreen(),
    );
  }
}
