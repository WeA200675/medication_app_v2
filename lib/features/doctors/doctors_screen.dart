import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_controller.dart';
import '../../core/doctor_search_service.dart';
import '../../core/models.dart';
import '../../shared/page_frame.dart';

class DoctorsScreen extends ConsumerWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(appControllerProvider).doctors;
    return PageFrame(
      title: 'Ärzte',
      subtitle: 'Kontakte und wichtige Aktionen – fehlende Angaben bleiben einfach ausgeblendet.',
      action: MenuAnchor(builder: (context, controller, child) => IconButton.filledTonal(onPressed: () => controller.isOpen ? controller.close() : controller.open(), icon: const Icon(Icons.add), tooltip: 'Arzt hinzufügen'), menuChildren: [MenuItemButton(leadingIcon: const Icon(Icons.search), onPressed: () => _search(context, ref), child: const Text('Online suchen')), MenuItemButton(leadingIcon: const Icon(Icons.edit_outlined), onPressed: () => _add(context, ref), child: const Text('Manuell anlegen'))]),
      child: doctors.isEmpty
          ? const _EmptyDoctors()
          : LayoutBuilder(builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 760 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
              return Wrap(spacing: 16, runSpacing: 16, children: [for (final doctor in doctors) SizedBox(width: cardWidth, child: _DoctorCard(doctor: doctor))]);
            }),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final specialty = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final website = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Arzt hinzufügen'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name *')),
        const SizedBox(height: 10), TextField(controller: specialty, decoration: const InputDecoration(labelText: 'Fachrichtung')),
        const SizedBox(height: 10), TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse')),
        const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
        const SizedBox(height: 10), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-Mail')),
        const SizedBox(height: 10), TextField(controller: website, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Website')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern'))],
    ));
    if (accepted == true && name.text.trim().isNotEmpty) {
      await ref.read(appControllerProvider).addDoctor(Doctor(id: '', name: name.text.trim(), specialty: specialty.text.trim(), address: address.text.trim(), phone: phone.text.trim(), email: email.text.trim(), website: website.text.trim()));
    }
  }

  Future<void> _search(BuildContext context, WidgetRef ref) async {
    final query = TextEditingController();
    List<Doctor> results = const [];
    var loading = false;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Arzt online suchen'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        SearchBar(controller: query, hintText: 'Name, Fachrichtung und Ort', trailing: [IconButton(onPressed: loading ? null : () async {
          setDialogState(() => loading = true);
          try {
            results = await DoctorSearchService.search(query.text);
          } finally {
            setDialogState(() => loading = false);
          }
        }, icon: const Icon(Icons.search))]),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        Flexible(child: ListView(shrinkWrap: true, children: [for (final doctor in results) ListTile(title: Text(doctor.name), subtitle: Text(doctor.address, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.add_circle_outline), onTap: () async {
          await ref.read(appControllerProvider).addDoctor(doctor);
          if (context.mounted) Navigator.pop(context);
        })])),
        const SizedBox(height: 8), const Align(alignment: Alignment.centerRight, child: Text('Daten © OpenStreetMap-Mitwirkende', style: TextStyle(fontSize: 11))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
    )));
  }
}

class _DoctorCard extends ConsumerWidget {
  const _DoctorCard({required this.doctor});
  final Doctor doctor;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [CircleAvatar(child: Text(doctor.name.characters.first.toUpperCase())), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(doctor.name, style: Theme.of(context).textTheme.titleLarge), if (doctor.specialty.isNotEmpty) Text(doctor.specialty)])), IconButton(onPressed: () => ref.read(appControllerProvider).removeDoctor(doctor.id), icon: const Icon(Icons.delete_outline), tooltip: 'Löschen')]),
    if (doctor.address.isNotEmpty) ...[const SizedBox(height: 16), Text(doctor.address)],
    const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [
      if (doctor.phone.isNotEmpty) ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Anrufen'), onPressed: () => _open(Uri(scheme: 'tel', path: doctor.phone))),
      if (doctor.email.isNotEmpty) ActionChip(avatar: const Icon(Icons.email_outlined, size: 18), label: const Text('E-Mail'), onPressed: () => _open(Uri(scheme: 'mailto', path: doctor.email))),
      if (doctor.website.isNotEmpty) ActionChip(avatar: const Icon(Icons.language, size: 18), label: const Text('Website'), onPressed: () => _open(_webUri(doctor.website))),
      if (doctor.address.isNotEmpty) ActionChip(avatar: const Icon(Icons.directions_outlined, size: 18), label: const Text('Route'), onPressed: () => _open(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': doctor.address}))),
    ]),
  ])));

  Future<void> _open(Uri uri) async => launchUrl(uri, mode: LaunchMode.externalApplication);
  Uri _webUri(String value) => Uri.tryParse(value)?.hasScheme == true ? Uri.parse(value) : Uri.parse('https://$value');
}

class _EmptyDoctors extends StatelessWidget {
  const _EmptyDoctors();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [const Icon(Icons.local_hospital_outlined, size: 52), const SizedBox(height: 16), Text('Noch keine Ärzte', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), const Text('Lege Praxen manuell an. Externe Suche folgt nach konfigurierter Datenquelle.')]))));
}
