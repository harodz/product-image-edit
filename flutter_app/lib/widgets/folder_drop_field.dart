import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

/// Folder or single image path. [onTextChanged] is for typing in the field; [onResolvedPick]
/// is for drop / browse (handles folders and image files). If [onImageFilesPicked] is provided,
/// a "Select Image(s)" button is shown that lets the user pick individual image files.
class FolderDropField extends StatefulWidget {
  const FolderDropField({
    required this.label,
    required this.value,
    required this.onTextChanged,
    required this.onResolvedPick,
    this.onImageFilesPicked,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onResolvedPick;
  final ValueChanged<List<String>>? onImageFilesPicked;

  @override
  State<FolderDropField> createState() => _FolderDropFieldState();
}

class _FolderDropFieldState extends State<FolderDropField> {
  bool _isDragging = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant FolderDropField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: _onDragDone,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging ? AppTokens.primary : AppTokens.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(10),
              color: AppTokens.surfaceLow,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_open, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _controller,
                        onChanged: widget.onTextChanged,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: l10n.dropFolderHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onImageFilesPicked != null)
                        OutlinedButton.icon(
                          onPressed: _pickImageFiles,
                          icon: const Icon(Icons.image_outlined, size: 14),
                          label: Text(l10n.selectImages),
                        ),
                      OutlinedButton(
                        onPressed: _pickFolder,
                        child: Text(l10n.browseFolder),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFolder() async {
    String? selected;
    try {
      selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context)!.dialogSelectFolder,
      );
    } on MissingPluginException {
      selected = await _pickFolderWithMacOsScript();
    } on PlatformException {
      selected = await _pickFolderWithMacOsScript();
    }
    if (selected != null) {
      widget.onResolvedPick(selected);
    }
  }

  Future<void> _pickImageFiles() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: AppLocalizations.of(context)!.dialogSelectImages,
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
    } on MissingPluginException {
      await _pickImageFilesWithMacOsScript();
      return;
    } on PlatformException {
      await _pickImageFilesWithMacOsScript();
      return;
    }
    if (result != null && result.paths.isNotEmpty) {
      final paths = result.paths.whereType<String>().toList();
      if (paths.isNotEmpty) {
        widget.onImageFilesPicked!(paths);
      }
    }
  }

  Future<void> _pickImageFilesWithMacOsScript() async {
    if (!Platform.isMacOS) return;
    final prompt = AppLocalizations.of(context)!.dialogSelectImages.replaceAll('"', r'\"');
    final result = await Process.run('osascript', [
      '-e',
      'set theFiles to choose file of type {"public.jpeg", "public.png", "org.webmproject.webp"} with prompt "$prompt" with multiple selections allowed\n'
          'set out to ""\n'
          'repeat with f in theFiles\n'
          'set out to out & POSIX path of f & (character id 10)\n'
          'end repeat\n'
          'return out',
    ]);
    if (result.exitCode != 0) return;
    final output = (result.stdout as String).trim();
    if (output.isEmpty) return;
    final paths = output.split('\n').where((p) => p.isNotEmpty).toList();
    if (paths.isNotEmpty) widget.onImageFilesPicked!(paths);
  }

  Future<void> _onDragDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    for (final file in details.files) {
      final path = file.path;
      if (Directory(path).existsSync() || File(path).existsSync()) {
        widget.onResolvedPick(path);
        break;
      }
    }
  }

  Future<String?> _pickFolderWithMacOsScript() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final prompt = AppLocalizations.of(context)!.dialogSelectFolder.replaceAll('"', r'\"');
    final result = await Process.run('osascript', [
      '-e',
      'POSIX path of (choose folder with prompt "$prompt")',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = (result.stdout as String).trim();
    if (output.isEmpty) {
      return null;
    }
    return output;
  }
}
