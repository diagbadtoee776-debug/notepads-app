import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const NotepadsApp());

class NotepadsApp extends StatelessWidget {
  const NotepadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notepads',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}