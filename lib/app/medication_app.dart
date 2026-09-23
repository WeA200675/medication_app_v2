import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_controller.dart';
import '../features/shell/app_shell.dart';
import 'app_theme.dart';

class MedicationApp extends ConsumerWidget {
  const MedicationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final settings = state.settings;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medication App',
      themeMode: settings.themeMode,
      theme: buildAppTheme(brightness: Brightness.light, seed: settings.accent),
      darkTheme: buildAppTheme(brightness: Brightness.dark, seed: settings.accent),
      home: Stack(
        fit: StackFit.expand,
        children: [
          if (settings.backgroundPath != null &&
              File(settings.backgroundPath!).existsSync())
            Image.file(File(settings.backgroundPath!), fit: BoxFit.cover),
          ColoredBox(
            color: Colors.black.withValues(alpha: settings.backgroundOverlay),
          ),
          const AppShell(),
        ],
      ),
    );
  }
}
