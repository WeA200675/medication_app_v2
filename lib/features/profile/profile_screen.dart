import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../../shared/page_frame.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const accents = [Color(0xff006b5f), Color(0xff375da9), Color(0xff7c4d9e), Color(0xffa14736)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final profile = state.profile;
    final settings = state.settings;
    final avatarExists = profile.avatarPath != null && File(profile.avatarPath!).existsSync();
    return PageFrame(
      title: 'Profil & Design',
      subtitle: 'Deine Daten bleiben lokal auf diesem Gerät.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
          GestureDetector(onTap: () => _chooseAvatar(ref), child: CircleAvatar(radius: 42, backgroundImage: avatarExists ? FileImage(File(profile.avatarPath!)) : null, child: avatarExists ? null : const Icon(Icons.add_a_photo_outlined, size: 30))),
          const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name.isEmpty ? 'Dein Profil' : profile.name, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 4), Text(profile.email.isEmpty ? 'Noch keine E-Mail hinterlegt' : profile.email)])),
          IconButton.filledTonal(onPressed: () => _editProfile(context, ref), icon: const Icon(Icons.edit_outlined), tooltip: 'Profil bearbeiten'),
        ]))),
        const SizedBox(height: 22), Text('Darstellung', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          SegmentedButton<ThemeMode>(segments: const [ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)), ButtonSegment(value: ThemeMode.light, label: Text('Hell'), icon: Icon(Icons.light_mode)), ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel'), icon: Icon(Icons.dark_mode))], selected: {settings.themeMode}, onSelectionChanged: (value) => ref.read(appControllerProvider).updateAppearance(settings.copyWith(themeMode: value.first))),
          const SizedBox(height: 22),
          Row(children: [const Expanded(child: Text('Akzentfarbe')), for (final color in accents) Padding(padding: const EdgeInsets.only(left: 10), child: Semantics(label: 'Akzentfarbe auswählen', button: true, child: InkWell(borderRadius: BorderRadius.circular(30), onTap: () => ref.read(appControllerProvider).updateAppearance(settings.copyWith(accent: color)), child: CircleAvatar(radius: 18, backgroundColor: color, child: color == settings.accent ? const Icon(Icons.check, color: Colors.white, size: 18) : null))))]),
          const Divider(height: 32),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.wallpaper_outlined), title: const Text('Hintergrundbild'), subtitle: Text(settings.backgroundPath == null ? 'Keines ausgewählt' : 'Aktiv · Änderung erscheint sofort'), trailing: FilledButton.tonal(onPressed: () => _chooseBackground(ref), child: const Text('Auswählen'))),
          if (settings.backgroundPath != null) ...[const SizedBox(height: 8), Row(children: [const Text('Abdunklung'), Expanded(child: Slider(value: settings.backgroundOverlay, min: .25, max: .9, onChanged: (value) => ref.read(appControllerProvider).updateAppearance(settings.copyWith(backgroundOverlay: value))))])],
        ]))),
        const SizedBox(height: 22), Text('Datenübernahme', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
        Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: const CircleAvatar(child: Icon(Icons.move_to_inbox_outlined)), title: const Text('V1-Backup importieren'), subtitle: const Text('Vorhandene Medikamente aus einem JSON-Backup übernehmen.'), trailing: const Icon(Icons.chevron_right), onTap: () => _importV1(context, ref))),
        const SizedBox(height: 12),
        Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: const CircleAvatar(child: Icon(Icons.ios_share_outlined)), title: const Text('V2-Backup exportieren'), subtitle: const Text('Medikamente, Ärzte, Dokumentverweise und Historie sichern.'), trailing: const Icon(Icons.chevron_right), onTap: () => _export(ref))),
      ]),
    );
  }

  Future<void> _chooseAvatar(WidgetRef ref) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
    if (image == null) return;
    final controller = ref.read(appControllerProvider);
    final path = await controller.persistAsset(image.path);
    await controller.saveProfile(controller.profile.copyWith(avatarPath: path));
  }

  Future<void> _chooseBackground(WidgetRef ref) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2400);
    if (image == null) return;
    final controller = ref.read(appControllerProvider);
    final path = await controller.persistAsset(image.path);
    await controller.updateAppearance(controller.settings.copyWith(backgroundPath: path));
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appControllerProvider).profile;
    final name = TextEditingController(text: current.name);
    final email = TextEditingController(text: current.email);
    final phone = TextEditingController(text: current.phone);
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Profil bearbeiten'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: 10), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-Mail')), const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern'))]));
    if (accepted == true) await ref.read(appControllerProvider).saveProfile(UserProfile(name: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), avatarPath: current.avatarPath));
  }

  Future<void> _importV1(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;
    try {
      final count = await ref.read(appControllerProvider).importV1(path);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Medikamente importiert.')));
    } on FormatException catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _export(WidgetRef ref) async {
    final path = await ref.read(appControllerProvider).exportBackup();
    await Share.shareXFiles([XFile(path)], subject: 'Medication App V2 Backup');
  }
}
