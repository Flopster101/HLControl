import 'package:flutter/material.dart';
import 'src/ui/screens/home_screen.dart';
import 'src/ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HlControlApp());
}

class HlControlApp extends StatelessWidget {
  const HlControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HL Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
