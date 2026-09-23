import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_controller.dart';
import '../../core/ocr_service.dart';
import '../../shared/page_frame.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(appControllerProvider).documents;
    return PageFrame(
      title: 'Dokumente',
      subtitle: 'Originaldateien werden lokal und unverändert gespeichert.',
      action: PopupMenuButton<String>(icon: const Icon(Icons.add), tooltip: 'Dokument hinzufügen', onSelected: (value) => value == 'camera' ? _camera(context, ref) : _file(context, ref), itemBuilder: (_) => const [PopupMenuItem(value: 'camera', child: ListTile(leading: Icon(Icons.camera_alt_outlined), title: Text('Fotografieren'))), PopupMenuItem(value: 'file', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Datei auswählen')))]),
      child: documents.isEmpty
          ? const _EmptyDocuments()
          : Column(children: [for (final doc in documents) Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: const CircleAvatar(child: Icon(Icons.description_outlined)), title: Text(doc.title), subtitle: Text(doc.ocrText.isEmpty ? '${doc.createdAt.day}.${doc.createdAt.month}.${doc.createdAt.year}' : doc.ocrText, maxLines: 2, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.open_in_new), onTap: () => launchUrl(Uri.file(doc.path), mode: LaunchMode.externalApplication))]),
    );
  }

  Future<void> _camera(BuildContext context, WidgetRef ref) async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
    if (image != null && context.mounted) await _save(context, ref, image.path, 'Foto ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}', recognizeText: true);
  }

  Future<void> _file(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    final path = result?.files.single.path;
    if (path != null && context.mounted) await _save(context, ref, path, result!.files.single.name, recognizeText: RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(path));
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String path, String defaultTitle, {bool recognizeText = false}) async {
    if (!File(path).existsSync()) return;
    final title = TextEditingController(text: defaultTitle);
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Dokument speichern'), content: TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Titel')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern'))]));
    if (accepted == true && title.text.trim().isNotEmpty) {
      var ocrText = '';
      if (recognizeText) {
        try {
          ocrText = await OcrService.recognize(path);
        } catch (_) {
          ocrText = '';
        }
      }
      await ref.read(appControllerProvider).addDocument(path, title.text.trim(), ocrText: ocrText);
    }
  }
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [const Icon(Icons.folder_open_outlined, size: 52), const SizedBox(height: 16), Text('Noch keine Dokumente', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), const Text('Fotografiere einen Arztbrief oder importiere PDF- und Bilddateien.')]))));
}
