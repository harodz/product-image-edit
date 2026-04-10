import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';

class OutputReviewGalleryScreen extends StatefulWidget {
  const OutputReviewGalleryScreen({super.key});

  @override
  State<OutputReviewGalleryScreen> createState() =>
      _OutputReviewGalleryScreenState();
}

class _OutputReviewGalleryScreenState
    extends State<OutputReviewGalleryScreen> {
  final Set<String> _selected = {};
  _Filter _filter = _Filter.all;

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  void _selectAll(List<OutputReviewItem> items) {
    setState(() => _selected.addAll(items.map((it) => it.path)));
  }

  void _deselectAll() {
    setState(() => _selected.clear());
  }

  void _batchApprove(AppState appState) {
    for (final path in _selected) {
      appState.setReviewStatus(path, ReviewStatus.approved);
    }
    _deselectAll();
  }

  void _batchReject(AppState appState) {
    for (final path in _selected) {
      appState.setReviewStatus(path, ReviewStatus.rejected);
    }
    _deselectAll();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final allItems = appState.snapshot.reviewItems;
    final items = _applyFilter(allItems);

    return AppShell(
      title: l10n.screenOutputGallery,
      child: Stack(
        children: [
          Column(
            children: [
              // ── Filter bar ──────────────────────────────────────────────
              Panel(
                child: Row(
                  children: [
                    // Summary count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.outputItemCount(allItems.length),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.processedLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTokens.onBackground.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppTokens.spacingLg),
                    // Filter tabs
                    Expanded(
                      child: Wrap(
                        spacing: AppTokens.spacingSm,
                        runSpacing: AppTokens.spacingSm,
                        children: [
                          _FilterTab(
                            label: l10n.filterAll,
                            count: allItems.length,
                            active: _filter == _Filter.all,
                            onTap: () => setState(() {
                              _filter = _Filter.all;
                              _selected.clear();
                            }),
                          ),
                          _FilterTab(
                            label: l10n.filterApproved,
                            count: allItems
                                .where((it) =>
                                    it.status == ReviewStatus.approved)
                                .length,
                            active: _filter == _Filter.approved,
                            color: AppTokens.success,
                            onTap: () => setState(() {
                              _filter = _Filter.approved;
                              _selected.clear();
                            }),
                          ),
                          _FilterTab(
                            label: l10n.filterNeedsEdit,
                            count: allItems
                                .where((it) =>
                                    it.status == ReviewStatus.needsEdit)
                                .length,
                            active: _filter == _Filter.needsEdit,
                            color: AppTokens.secondary,
                            onTap: () => setState(() {
                              _filter = _Filter.needsEdit;
                              _selected.clear();
                            }),
                          ),
                          _FilterTab(
                            label: l10n.filterRejected,
                            count: allItems
                                .where((it) =>
                                    it.status == ReviewStatus.rejected)
                                .length,
                            active: _filter == _Filter.rejected,
                            color: AppTokens.error,
                            onTap: () => setState(() {
                              _filter = _Filter.rejected;
                              _selected.clear();
                            }),
                          ),
                          _FilterTab(
                            label: l10n.filterUnreviewed,
                            count: allItems
                                .where((it) =>
                                    it.status == ReviewStatus.unreviewed)
                                .length,
                            active: _filter == _Filter.unreviewed,
                            onTap: () => setState(() {
                              _filter = _Filter.unreviewed;
                              _selected.clear();
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTokens.spacingSm),
                    // Select all / refresh
                    if (items.isNotEmpty) ...[
                      _IconBtn(
                        icon: Icons.select_all,
                        tooltip: l10n.tooltipSelectAll,
                        onTap: () => _selectAll(items),
                      ),
                      const SizedBox(width: 4),
                      _IconBtn(
                        icon: Icons.deselect,
                        tooltip: l10n.tooltipDeselectAll,
                        onTap: _deselectAll,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _IconBtn(
                      icon: Icons.refresh,
                      tooltip: l10n.tooltipRefresh,
                      onTap: appState.refreshOutputReviews,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.spacingMd),
              // ── Grid ─────────────────────────────────────────────────────
              Expanded(
                child: items.isEmpty
                    ? Panel(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 40,
                                color: AppTokens.onBackground
                                    .withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.noImagesInView,
                                style: TextStyle(
                                  color: AppTokens.onBackground
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: _selected.isNotEmpty
                            ? const EdgeInsets.only(bottom: 72)
                            : EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: AppTokens.spacingSm,
                          mainAxisSpacing: AppTokens.spacingSm,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final isSelected = _selected.contains(item.path);
                          final statusColor = switch (item.status) {
                            ReviewStatus.approved => AppTokens.success,
                            ReviewStatus.needsEdit => AppTokens.secondary,
                            ReviewStatus.rejected => AppTokens.error,
                            ReviewStatus.unreviewed => AppTokens.outlineVariant,
                          };
                          return _ImageCard(
                            item: item,
                            statusColor: statusColor,
                            isSelected: isSelected,
                            onToggleSelect: () => _toggleSelect(item.path),
                            onDoubleTap: () => _openLightbox(context, item),
                            onApprove: () => appState.setReviewStatus(
                              item.path,
                              ReviewStatus.approved,
                            ),
                            onNeedsEdit: () => appState.setReviewStatus(
                              item.path,
                              ReviewStatus.needsEdit,
                            ),
                            onReject: () => appState.setReviewStatus(
                              item.path,
                              ReviewStatus.rejected,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // ── Floating action bar ─────────────────────────────────────────
          if (_selected.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SelectionBar(
                count: _selected.length,
                onCancel: _deselectAll,
                onApprove: () => _batchApprove(appState),
                onReject: () => _batchReject(appState),
                l10n: l10n,
              ),
            ),
        ],
      ),
    );
  }

  List<OutputReviewItem> _applyFilter(List<OutputReviewItem> all) {
    return switch (_filter) {
      _Filter.approved =>
        all.where((it) => it.status == ReviewStatus.approved).toList(),
      _Filter.needsEdit =>
        all.where((it) => it.status == ReviewStatus.needsEdit).toList(),
      _Filter.rejected =>
        all.where((it) => it.status == ReviewStatus.rejected).toList(),
      _Filter.unreviewed =>
        all.where((it) => it.status == ReviewStatus.unreviewed).toList(),
      _Filter.all => all,
    };
  }

  void _openLightbox(BuildContext context, OutputReviewItem item) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => _LightboxDialog(item: item),
    );
  }
}

enum _Filter { all, approved, needsEdit, rejected, unreviewed }

// ── Image card ─────────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.item,
    required this.statusColor,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onDoubleTap,
    required this.onApprove,
    required this.onNeedsEdit,
    required this.onReject,
  });

  final OutputReviewItem item;
  final Color statusColor;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDoubleTap;
  final VoidCallback onApprove;
  final VoidCallback onNeedsEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleSelect,
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(
            color: isSelected
                ? AppTokens.primary.withValues(alpha: 0.6)
                : statusColor.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area with checkbox overlay
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTokens.radius - 1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTokens.surfaceHigh,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppTokens.onBackground.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    // Selection overlay
                    if (isSelected)
                      Container(
                        color: AppTokens.primary.withValues(alpha: 0.2),
                      ),
                    // Checkbox top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Checkbox(checked: isSelected),
                    ),
                    // Status badge top-right
                    if (item.status != ReviewStatus.unreviewed)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.status == ReviewStatus.approved
                                ? Icons.check
                                : item.status == ReviewStatus.rejected
                                    ? Icons.close
                                    : Icons.edit_outlined,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _MicroButton(label: '✓', onTap: onApprove, color: AppTokens.success),
                      _MicroButton(label: '~', onTap: onNeedsEdit, color: AppTokens.secondary),
                      _MicroButton(label: '✕', onTap: onReject, color: AppTokens.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? AppTokens.primary : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? AppTokens.primary : Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _MicroButton extends StatelessWidget {
  const _MicroButton({
    required this.label,
    required this.onTap,
    required this.color,
  });
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Filter tab ────────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTokens.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? c.withValues(alpha: 0.45)
                : AppTokens.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            color: active ? c : AppTokens.onBackground.withValues(alpha: 0.6),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Floating selection bar ─────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onApprove,
    required this.onReject,
    required this.l10n,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacingLg,
        vertical: AppTokens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTokens.surfaceHighest,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(
          color: AppTokens.outlineVariant.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTokens.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.itemsSelected(count),
              style: const TextStyle(
                fontSize: 13,
                color: AppTokens.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onCancel,
            child: Text(
              l10n.cancel,
              style: TextStyle(color: AppTokens.onBackground.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: AppTokens.spacingSm),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 14),
            label: Text(l10n.rejectSelected),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTokens.error,
              side: BorderSide(color: AppTokens.error.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(width: AppTokens.spacingSm),
          ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check, size: 14),
            label: Text(l10n.approveSelected),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primaryContainer,
              foregroundColor: AppTokens.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lightbox dialog ───────────────────────────────────────────────────────────

class _LightboxDialog extends StatefulWidget {
  const _LightboxDialog({required this.item});
  final OutputReviewItem item;

  @override
  State<_LightboxDialog> createState() => _LightboxDialogState();
}

class _LightboxDialogState extends State<_LightboxDialog> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() => _transformController.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 64,
            maxHeight: MediaQuery.of(context).size.height - 64,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      size: 14,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tooltip(
                      message: 'Reset zoom',
                      child: InkWell(
                        onTap: _resetZoom,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.zoom_out_map,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Close  (Esc)',
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Image area
              Flexible(
                child: GestureDetector(
                  // Double-tap resets zoom; single-tap on background closes
                  onDoubleTap: _resetZoom,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF141414),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(10)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10)),
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.5,
                        maxScale: 8.0,
                        child: Image.file(
                          File(widget.item.path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTokens.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTokens.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppTokens.onBackground.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
