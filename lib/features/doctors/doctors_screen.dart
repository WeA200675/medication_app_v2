import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_controller.dart';
import '../../core/doctor_search_service.dart';
import '../../core/models.dart';
import '../../shared/page_frame.dart';

class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  String filter = '';
  final localSearchController = TextEditingController();
  final doctorSearch = DoctorSearchService();

  static const specialties = [
    'Alle Fachrichtungen', 'Hausarzt', 'Allgemeinmedizin', 'Innere Medizin',
    'Kardiologie', 'Dermatologie', 'Orthopädie', 'Neurologie', 'Psychiatrie',
    'Psychotherapie', 'Gynäkologie', 'Urologie', 'Pädiatrie', 'HNO',
    'Augenheilkunde', 'Zahnmedizin', 'Gastroenterologie', 'Diabetologie',
  ];

  @override
  void dispose() {
    localSearchController.dispose();
    doctorSearch.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(appControllerProvider).doctors.where((doctor) {
      final query = filter.trim().toLowerCase();
      return query.isEmpty ||
          doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query) ||
          doctor.address.toLowerCase().contains(query);
    }).toList();
    return PageFrame(
      title: 'Ärzte',
      subtitle: 'Kontakte, Fachrichtungen, Termine und Nachrichten.',
      action: MenuAnchor(
        builder: (context, controller, child) => IconButton.filledTonal(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add),
          tooltip: 'Arzt hinzufügen',
        ),
        menuChildren: [
          MenuItemButton(leadingIcon: const Icon(Icons.travel_explore), onPressed: () => _searchOnline(context), child: const Text('Im Umkreis suchen')),
          MenuItemButton(leadingIcon: const Icon(Icons.edit_outlined), onPressed: () => _editDoctor(context), child: const Text('Manuell anlegen')),
        ],
      ),
      child: Column(children: [
        SearchBar(
          controller: localSearchController,
          hintText: 'Gespeicherte Ärzte oder Fachrichtung filtern',
          leading: const Icon(Icons.search),
          trailing: filter.isEmpty ? null : [IconButton(
            icon: const Icon(Icons.close), tooltip: 'Suchbegriff löschen',
            onPressed: () { localSearchController.clear(); setState(() => filter = ''); },
          )],
          onChanged: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 18),
        if (doctors.isEmpty)
          _EmptyDoctors(hasFilter: filter.isNotEmpty)
        else
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth >= 760 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final doctor in doctors) SizedBox(width: width, child: _DoctorCard(doctor: doctor, onEdit: () => _editDoctor(context, doctor: doctor))),
            ]);
          }),
      ]),
    );
  }

  Future<void> _editDoctor(BuildContext context, {Doctor? doctor}) async {
    final result = await showDialog<Doctor>(context: context, builder: (_) => _DoctorFormDialog(doctor: doctor));
    if (result != null) await ref.read(appControllerProvider).addDoctor(result);
  }

  Future<void> _searchOnline(BuildContext context) async {
    final query = TextEditingController();
    final location = TextEditingController();
    var specialty = specialties.first;
    var radius = 10.0;
    var loading = false;
    String? error;
    List<String> notices = const [];
    List<Doctor> results = const [];
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      scrollable: true,
      title: const Text('Arzt im Umkreis suchen'),
      content: SizedBox(width: 600, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          initialValue: specialty,
          decoration: const InputDecoration(labelText: 'Fachrichtung'),
          items: specialties.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
          onChanged: (value) => setDialogState(() => specialty = value ?? specialties.first),
        ),
        const SizedBox(height: 10),
        TextField(controller: query, decoration: const InputDecoration(labelText: 'Optional: Name oder Behandlungsthema', hintText: 'z. B. Haut, Rücken oder Diabetes')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: location, decoration: const InputDecoration(labelText: 'Ort oder Postleitzahl'))),
          const SizedBox(width: 10),
          DropdownButton<double>(value: radius, items: const [5, 10, 25, 50, 100].map((value) => DropdownMenuItem(value: value.toDouble(), child: Text('$value km'))).toList(), onChanged: (value) => setDialogState(() => radius = value ?? 10)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: loading ? null : () async {
            FocusManager.instance.primaryFocus?.unfocus();
            setDialogState(() {
              loading = true;
              error = null;
              notices = const [];
            });
            try {
              final searchTerm = [if (specialty != specialties.first) specialty, query.text.trim()].where((value) => value.isNotEmpty).join(' ');
              final response = await doctorSearch.search(
                query: searchTerm,
                location: location.text,
                radiusKm: radius,
              );
              if (!context.mounted) return;
              results = response.doctors;
              notices = response.notices;
              if (results.isEmpty) error = 'Keine passenden Treffer in diesem Radius gefunden.';
            } catch (exception) {
              if (!context.mounted) return;
              error = exception.toString().replaceFirst('Exception: ', '');
            } finally {
              if (context.mounted) {
                setDialogState(() => loading = false);
              }
            }
          },
          icon: const Icon(Icons.search), label: const Text('Suchen'),
        )),
        if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(notice)),
              ],
            ),
          ),
        SizedBox(height: 220, child: ListView(children: [
          for (final doctor in results)
            ListTile(
              title: Text(doctor.name),
              subtitle: Text([
                doctor.specialty,
                doctor.address,
                if (doctor.distanceKm != null)
                  '${doctor.distanceKm!.toStringAsFixed(1)} km entfernt',
                'Quelle: ${doctor.sourceName}',
              ].where((value) => value.isNotEmpty).join('\n'), maxLines: 5, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Prüfen und übernehmen',
                onPressed: () => _reviewSearchResult(context, doctor),
              ),
              onTap: () async {
                await _reviewSearchResult(context, doctor);
              },
            ),
        ])),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
          TextButton.icon(onPressed: () => launchUrl(Uri.parse('https://arztsuche.116117.de/'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.health_and_safety_outlined), label: const Text('116117-Arztsuche')),
          const Text('Daten © OpenStreetMap-Mitwirkende', style: TextStyle(fontSize: 11)),
        ]),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
    )));
  }

  Future<void> _reviewSearchResult(
    BuildContext context,
    Doctor doctor,
  ) async {
    var candidate = doctor;
    if (doctor.website.isNotEmpty &&
        (doctor.phone.isEmpty ||
            doctor.email.isEmpty ||
            doctor.appointmentUrl.isEmpty)) {
      final enrich = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kontaktdaten ergänzen?'),
          content: const Text(
            'Die App kann die öffentlich sichtbaren Kontakt- und Terminlinks '
            'der hinterlegten Praxiswebseite auslesen. Alle Angaben werden '
            'anschließend vor dem Speichern angezeigt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ohne Ergänzung'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Praxiswebseite prüfen'),
            ),
          ],
        ),
      );
      if (enrich == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Praxiswebseite wird geprüft …')),
          );
        }
        try {
          candidate = await doctorSearch.enrichFromWebsite(doctor);
        } catch (exception) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  exception.toString().replaceFirst('Exception: ', ''),
                ),
              ),
            );
          }
        }
      }
    }
    if (!context.mounted) return;
    final reviewed = await showDialog<Doctor>(
      context: context,
      builder: (_) => _DoctorFormDialog(doctor: candidate),
    );
    if (reviewed != null) {
      await ref.read(appControllerProvider).addDoctor(reviewed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${reviewed.name} gespeichert.')),
        );
      }
    }
  }
}

class _DoctorFormDialog extends StatefulWidget {
  const _DoctorFormDialog({this.doctor});
  final Doctor? doctor;

  @override
  State<_DoctorFormDialog> createState() => _DoctorFormDialogState();
}

class _DoctorFormDialogState extends State<_DoctorFormDialog> {
  late final TextEditingController name;
  late final TextEditingController specialty;
  late final TextEditingController address;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController website;
  late final TextEditingController appointment;
  late final TextEditingController openingHours;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.doctor?.name ?? '');
    specialty = TextEditingController(text: widget.doctor?.specialty ?? '');
    address = TextEditingController(text: widget.doctor?.address ?? '');
    phone = TextEditingController(text: widget.doctor?.phone ?? '');
    email = TextEditingController(text: widget.doctor?.email ?? '');
    website = TextEditingController(text: widget.doctor?.website ?? '');
    appointment = TextEditingController(text: widget.doctor?.appointmentUrl ?? '');
    openingHours = TextEditingController(text: widget.doctor?.openingHours ?? '');
  }

  @override
  void dispose() {
    name.dispose(); specialty.dispose(); address.dispose(); phone.dispose();
    email.dispose(); website.dispose(); appointment.dispose(); openingHours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.doctor == null ? 'Arzt hinzufügen' : 'Arzt bearbeiten'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _field(name, 'Name *', Icons.person_outline),
      _field(specialty, 'Fachrichtung / Behandlungsschwerpunkte', Icons.medical_services_outlined),
      _field(address, 'Adresse', Icons.location_on_outlined),
      _field(phone, 'Telefonnummer', Icons.call_outlined, type: TextInputType.phone),
      _field(email, 'E-Mail für Rezepte und Nachrichten', Icons.email_outlined, type: TextInputType.emailAddress),
      _field(website, 'Webseite', Icons.language, type: TextInputType.url),
      _field(appointment, 'Link zur Terminvereinbarung', Icons.event_available_outlined, type: TextInputType.url),
      _field(openingHours, 'Öffnungszeiten', Icons.schedule_outlined),
      if (widget.doctor != null)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Quelle: ${widget.doctor!.sourceName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(context, Doctor(
        id: widget.doctor?.id ?? '', name: name.text.trim(), specialty: specialty.text.trim(), address: address.text.trim(),
        phone: phone.text.trim(), email: email.text.trim(), website: website.text.trim(), appointmentUrl: appointment.text.trim(),
        openingHours: openingHours.text.trim(),
        latitude: widget.doctor?.latitude, longitude: widget.doctor?.longitude,
        distanceKm: widget.doctor?.distanceKm,
        sourceName: widget.doctor?.sourceName ?? 'Manuell',
        sourceUrl: widget.doctor?.sourceUrl ?? '',
        lastVerifiedAt: widget.doctor?.lastVerifiedAt,
      )), child: const Text('Speichern')),
    ],
  );

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, keyboardType: type, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
  );
}

class _DoctorCard extends ConsumerWidget {
  const _DoctorCard({required this.doctor, required this.onEdit});
  final Doctor doctor;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      CircleAvatar(child: Text(doctor.name.characters.first.toUpperCase())), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(doctor.name, style: Theme.of(context).textTheme.titleLarge), if (doctor.specialty.isNotEmpty) Text(doctor.specialty)])),
      PopupMenuButton<String>(onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') _confirmDelete(context, ref);
      }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Bearbeiten')), PopupMenuItem(value: 'delete', child: Text('Löschen'))]),
    ]),
    if (doctor.address.isNotEmpty) ...[const SizedBox(height: 14), Text(doctor.address)],
    if (doctor.openingHours.isNotEmpty) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.schedule_outlined, size: 18), const SizedBox(width: 8), Expanded(child: Text(doctor.openingHours))])],
    if (doctor.sourceName != 'Manuell') ...[
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.verified_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Quelle: ${doctor.sourceName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    ],
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: [
      if (doctor.phone.isNotEmpty) ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Anrufen'), onPressed: () => _open(context, Uri(scheme: 'tel', path: doctor.phone))),
      if (doctor.email.isNotEmpty) ...[
        ActionChip(avatar: const Icon(Icons.medication_outlined, size: 18), label: const Text('Rezept'), onPressed: () => _prescriptionEmail(context, ref)),
        ActionChip(avatar: const Icon(Icons.email_outlined, size: 18), label: const Text('Nachricht'), onPressed: () => _open(context, Uri(scheme: 'mailto', path: doctor.email))),
      ],
      if (doctor.website.isNotEmpty) ActionChip(avatar: const Icon(Icons.language, size: 18), label: const Text('Webseite'), onPressed: () => _open(context, _webUri(doctor.website))),
      if (doctor.appointmentUrl.isNotEmpty)
        ActionChip(avatar: const Icon(Icons.event_available_outlined, size: 18), label: const Text('Termin'), onPressed: () => _open(context, _webUri(doctor.appointmentUrl)))
      else if (doctor.website.isNotEmpty)
        ActionChip(avatar: const Icon(Icons.event_outlined, size: 18), label: const Text('Termin anfragen'), tooltip: 'Praxiswebseite öffnen', onPressed: () => _open(context, _webUri(doctor.website))),
      if (doctor.address.isNotEmpty) ActionChip(avatar: const Icon(Icons.directions_outlined, size: 18), label: const Text('Route'), onPressed: () => _open(context, Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': doctor.address}))),
    ]),
  ])));

  Future<void> _prescriptionEmail(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(appControllerProvider);
    final medicines = state.medications.map((item) => '• ${item.name}').join('\n');
    final profile = state.profile;
    final body = 'Guten Tag,\n\nich möchte folgende Medikamente als Rezept bestellen:\n\n${medicines.isEmpty ? '• Bitte Medikament ergänzen' : medicines}\n\nPatient: ${profile.name}\nTelefon: ${profile.phone}\n\nMit freundlichen Grüßen\n${profile.name}';
    await _open(context, Uri(scheme: 'mailto', path: doctor.email, queryParameters: {'subject': 'Rezeptbestellung', 'body': body}));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arzt löschen?'),
        content: Text(
          '${doctor.name} wird aus deinen gespeicherten Ärzten entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider).removeDoctor(doctor.id);
    }
  }

  Future<void> _open(BuildContext? context, Uri uri) async {
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Der Link konnte nicht geöffnet werden.'),
          ),
        );
      }
    } on Object {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Der Link ist ungültig oder nicht erreichbar.'),
          ),
        );
      }
    }
  }
  Uri _webUri(String value) => Uri.tryParse(value)?.hasScheme == true ? Uri.parse(value) : Uri.parse('https://$value');
}

class _EmptyDoctors extends StatelessWidget {
  const _EmptyDoctors({required this.hasFilter});
  final bool hasFilter;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [
    const Icon(Icons.local_hospital_outlined, size: 52), const SizedBox(height: 16),
    Text(hasFilter ? 'Keine passenden Ärzte' : 'Noch keine Ärzte', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6), Text(hasFilter ? 'Versuche einen anderen Namen oder eine andere Fachrichtung.' : 'Lege eine Praxis an oder suche nach Fachrichtung und Umkreis.', textAlign: TextAlign.center),
  ]))));
}
