import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/presentation/home_screen.dart';

void main() {
  runApp(const MementoApp());
}

class MementoApp extends StatelessWidget {
  const MementoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memento',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
