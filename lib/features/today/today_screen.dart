import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_controller.dart';
import '../../core/quantity_formatter.dart';
import '../../shared/page_frame.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final critical = state.medications.where((e) => e.needsRefill).toList();
    return PageFrame(
      title: _greeting(),
      subtitle: state.profile.name.isEmpty ? 'Dein Gesundheitsüberblick' : '${state.profile.name}, hier ist dein Gesundheitsüberblick.',
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final width = columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          SizedBox(width: width, child: _NextMedicationCard(state: state)),
          SizedBox(width: width, child: _InventoryCard(count: critical.length)),
          SizedBox(width: width, child: _ProfileCard(state: state)),
        ]);
      }),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }
}

class _NextMedicationCard extends ConsumerWidget {
  const _NextMedicationCard({required this.state});
  final AppController state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = state.medications.where((e) => e.isActive).toList();
    final med = active.isEmpty ? null : active.first;
    return Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.schedule_rounded, size: 32),
      const SizedBox(height: 18),
      Text('Nächste Einnahme', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(med == null ? 'Noch nichts geplant' : '${med.time} · ${med.name}', style: Theme.of(context).textTheme.headlineSmall),
      if (med != null) ...[
        const SizedBox(height: 6), Text(formatMedicationQuantity(med.dose, med.unit)), const SizedBox(height: 18),
        FilledButton.icon(onPressed: med.stock <= 0 ? null : () => ref.read(appControllerProvider).takeMedication(med), icon: const Icon(Icons.check), label: const Text('Als genommen markieren')),
      ],
    ])));
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(count == 0 ? Icons.inventory_2_outlined : Icons.warning_amber_rounded, size: 32, color: count == 0 ? null : Theme.of(context).colorScheme.error),
    const SizedBox(height: 18), Text('Medikamentenvorrat', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
    Text(count == 0 ? 'Alles ausreichend' : '$count ${count == 1 ? 'Präparat wird' : 'Präparate werden'} knapp', style: Theme.of(context).textTheme.headlineSmall),
  ])));
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state});
  final AppController state;
  @override
  Widget build(BuildContext context) {
    final path = state.profile.avatarPath;
    final hasImage = path != null && File(path).existsSync();
    return Card(child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
      CircleAvatar(radius: 30, backgroundImage: hasImage ? FileImage(File(path)) : null, child: hasImage ? null : const Icon(Icons.person, size: 30)),
      const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(state.profile.name.isEmpty ? 'Dein Profil' : state.profile.name, style: Theme.of(context).textTheme.titleLarge),
        Text(state.profile.email.isEmpty ? 'Profil vervollständigen' : state.profile.email),
      ])),
    ])));
  }
}

extension on double {
  String get g => this == roundToDouble() ? toInt().toString() : toString().replaceAll('.', ',');
}
