import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

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
      home: const _EmptyArchiveScreen(),
    );
  }
}

class _EmptyArchiveScreen extends StatelessWidget {
  const _EmptyArchiveScreen();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Memento', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Место, где мысли остаются навсегда.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
