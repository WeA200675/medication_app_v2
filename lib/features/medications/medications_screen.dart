import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../shared/page_frame.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return PageFrame(
      title: 'Medikamente',
      subtitle: 'Einnahme, Reichweite und Vorrat an einem Ort.',
      action: IconButton.filledTonal(onPressed: () => _showAdd(context, ref), icon: const Icon(Icons.add), tooltip: 'Medikament hinzufügen'),
      child: state.medications.isEmpty
          ? const _EmptyMedications()
          : Column(children: [
              for (final med in state.medications) ...[
                _MedicationCard(medication: med),
                const SizedBox(height: 14),
              ],
              if (state.medications.any((e) => e.needsRefill))
                Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _composeRefill(state.medications.where((e) => e.needsRefill)), icon: const Icon(Icons.outgoing_mail), label: const Text('Nachbestellung vorbereiten'))),
            ]),
    );
  }

  Future<void> _composeRefill(Iterable<Medication> meds) async {
    final list = meds.map((e) => '• ${e.name} (noch ${e.stock.g} ${e.unit})').join('\n');
    final uri = Uri(scheme: 'mailto', queryParameters: {'subject': 'Medikamente benötigt', 'body': 'Guten Tag,\n\nfolgende Medikamente werden benötigt:\n\n$list\n\nMit freundlichen Grüßen'});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAdd(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final dose = TextEditingController(text: '1');
    final stock = TextEditingController(text: '30');
    final minimum = TextEditingController(text: '7');
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Medikament hinzufügen'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12), TextField(controller: dose, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Dosis')),
        const SizedBox(height: 12), TextField(controller: stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bestand')),
        const SizedBox(height: 12), TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Mindestbestand')),
        const SizedBox(height: 12), ListTile(title: const Text('Einnahmezeit'), subtitle: Text(selectedTime.format(context)), trailing: const Icon(Icons.schedule), onTap: () async {
          final value = await showTimePicker(context: context, initialTime: selectedTime);
          if (value != null) setDialogState(() => selectedTime = value);
        }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern'))],
    )));
    if (accepted == true && name.text.trim().isNotEmpty) {
      await ref.read(appControllerProvider).addMedication(
        name: name.text.trim(), dose: _number(dose.text, 1), unit: 'Tablette',
        time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
        stock: _number(stock.text, 0), minimumStock: _number(minimum.text, 7),
      );
    }
  }

  double _number(String value, double fallback) => double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

class _MedicationCard extends ConsumerWidget {
  const _MedicationCard({required this.medication});
  final Medication medication;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = medication.needsRefill ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: .14), child: Icon(Icons.medication, color: color)),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(medication.name, style: Theme.of(context).textTheme.titleLarge), Text('${medication.dose.g} ${medication.unit} · ${medication.time}') ])),
        PopupMenuButton<String>(onSelected: (value) {
          if (value == 'refill') _refill(context, ref);
          if (value == 'delete') ref.read(appControllerProvider).removeMedication(medication.id);
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'refill', child: Text('Bestand auffüllen')), PopupMenuItem(value: 'delete', child: Text('Löschen'))]),
      ]),
      const SizedBox(height: 18),
      LinearProgressIndicator(value: medication.stock <= 0 ? 0 : (medication.stock / (medication.minimumStock * 3).clamp(1, double.infinity)).clamp(0, 1), minHeight: 8, borderRadius: BorderRadius.circular(8), color: color),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: Text('${medication.stock.g} ${medication.unit} · etwa ${medication.estimatedDays} Tage')), if (medication.needsRefill) Text('Nachbestellen', style: TextStyle(color: color, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 16),
      FilledButton.tonalIcon(onPressed: medication.stock < medication.dose ? null : () => ref.read(appControllerProvider).takeMedication(medication), icon: const Icon(Icons.check), label: const Text('Einnahme bestätigen')),
    ])));
  }

  Future<void> _refill(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '30');
    final value = await showDialog<double>(context: context, builder: (context) => AlertDialog(title: const Text('Bestand auffüllen'), content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: medication.unit)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))), child: const Text('Hinzufügen'))]));
    if (value != null && value > 0) await ref.read(appControllerProvider).refillMedication(medication, value);
  }
}

class _EmptyMedications extends StatelessWidget {
  const _EmptyMedications();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [Icon(Icons.medication_liquid_outlined, size: 52, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Noch keine Medikamente', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), const Text('Füge dein erstes Dauermedikament über das Plus hinzu.', textAlign: TextAlign.center)]))));
}

extension on double {
  String get g => this == roundToDouble() ? toInt().toString() : toString().replaceAll('.', ',');
}
