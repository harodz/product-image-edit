import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import '../widgets/folder_drop_field.dart';
import 'batch_dashboard_screen.dart';

const _kModelIds = [
  'gemini-3.1-flash-image-preview',
  'gemini-2.0-flash-exp',
  'gemini-1.5-pro',
];

class PipelineSettingsScreen extends StatelessWidget {
  const PipelineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppShell(
      title: l10n.screenPipelineSettings,
      child: const _Content(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  // Content-area width below which the two side-by-side columns collapse into
  // a single scrollable column.
  static const _kSingleColumnBreakpoint = 480.0;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < _kSingleColumnBreakpoint;

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConfigPanel(appState: appState),
            const SizedBox(height: AppTokens.spacingMd),
            _ExecutionPanel(appState: appState),
            const SizedBox(height: AppTokens.spacingMd),
            _ActionsPanel(appState: appState),
          ],
        );

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModelPanel(appState: appState),
            const SizedBox(height: AppTokens.spacingMd),
            Panel(child: _SummaryPanel(appState: appState)),
          ],
        );

        if (singleColumn) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn,
                const SizedBox(height: AppTokens.spacingMd),
                rightColumn,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: SingleChildScrollView(child: leftColumn),
            ),
            const SizedBox(width: AppTokens.spacingMd),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(child: rightColumn),
            ),
          ],
        );
      },
    );
  }
}

// ── Left column panels ────────────────────────────────────────────────────────

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = appState.config;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.sectionBatchConfiguration, icon: Icons.folder_open_outlined),
          const SizedBox(height: AppTokens.spacingMd),
          FolderDropField(
            label: l10n.inputFolderOrImage,
            value: cfg.inputDir,
            onTextChanged: appState.setInputDir,
            onResolvedPick: (path) => unawaited(appState.applyDroppedInputPath(path)),
            onImageFilesPicked: (paths) => unawaited(appState.applyImageFilesPicked(paths)),
          ),
          const SizedBox(height: AppTokens.spacingSm),
          FolderDropField(
            label: l10n.outputDirectory,
            value: cfg.outputDir,
            onTextChanged: appState.setOutputDir,
            onResolvedPick: appState.setOutputDir,
          ),
          if (appState.inputNotice != null) ...[
            const SizedBox(height: AppTokens.spacingSm),
            Text(
              appState.inputNotice!,
              style: const TextStyle(color: AppTokens.error, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = appState.config;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.sectionExecutionParameters, icon: Icons.bolt_outlined),
          const SizedBox(height: AppTokens.spacingMd),
          _SliderField(
            label: l10n.flagWorkers,
            value: cfg.workers.toDouble(),
            min: 1,
            max: 64,
            minLabel: l10n.workersMinLabel,
            maxLabel: l10n.workersMaxLabel,
            onChanged: appState.setWorkers,
          ),
          const SizedBox(height: AppTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.flagMaxApiRetries,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.maxApiRetriesHelp,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTokens.onBackground.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.spacingMd),
              _InlineStepper(
                value: cfg.maxApiRetries,
                min: 0,
                max: 20,
                onChanged: appState.setRetries,
              ),
            ],
          ),
          Divider(
            height: AppTokens.spacingLg,
            color: AppTokens.outlineVariant.withValues(alpha: 0.15),
          ),
          _ToggleRow(
            label: l10n.flagKeepRaw,
            subtitle: l10n.keepRawSubtitle,
            value: cfg.keepRaw,
            onChanged: appState.setFlagKeepRaw,
          ),
          _ToggleRow(
            label: l10n.flagFailFast,
            subtitle: l10n.failFastSubtitle,
            value: cfg.failFast,
            onChanged: appState.setFlagFailFast,
          ),
          const SizedBox(height: AppTokens.spacingSm),
          ExpansionTile(
            title: Text(
              l10n.moreOptions,
              style: const TextStyle(fontSize: 13),
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppTokens.spacingSm),
            collapsedShape: const Border(),
            shape: const Border(),
            children: [
              _LabeledField(
                label: l10n.promptLabel,
                value: cfg.prompt,
                maxLines: 3,
                onChanged: appState.setPrompt,
              ),
              const SizedBox(height: AppTokens.spacingSm),
              _ToggleRow(
                label: l10n.useResponseModalities,
                value: cfg.useResponseModalities,
                onChanged: appState.setFlagUseResponseModalities,
              ),
              _ToggleRow(
                label: l10n.copyFailed,
                value: cfg.copyFailed,
                onChanged: appState.setFlagCopyFailed,
              ),
              _ToggleRow(
                label: l10n.noProgress,
                value: cfg.noProgress,
                onChanged: appState.setFlagNoProgress,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appState.isRunning ? AppTokens.primary : AppTokens.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appState.isRunning ? l10n.pipelineRunning : l10n.allSystemsOperational,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTokens.onBackground.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacingSm),
          Wrap(
            spacing: AppTokens.spacingSm,
            runSpacing: AppTokens.spacingSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              if (appState.isRunning)
                OutlinedButton(
                  onPressed: appState.cancelPipeline,
                  child: Text(l10n.cancel),
                ),
              OutlinedButton(
                onPressed: () => _showPreview(context, appState.commandPreview),
                child: Text(l10n.previewCommand),
              ),
              ElevatedButton(
                onPressed: appState.isRunning
                    ? null
                    : () => _runAndNavigate(context, appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.primaryContainer,
                  foregroundColor: AppTokens.onBackground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spacingLg,
                    vertical: AppTokens.spacingSm,
                  ),
                ),
                child: Text(appState.isRunning ? l10n.runningEllipsis : l10n.runPipeline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _runAndNavigate(BuildContext context, AppState appState) {
    late void Function() listener;
    listener = () {
      if (!context.mounted) {
        appState.removeListener(listener);
        return;
      }
      if (appState.isRunning) {
        appState.removeListener(listener);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            settings:
                const RouteSettings(name: AppRouter.batchDashboardRoute),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, _, __) => const BatchDashboardScreen(),
          ),
        );
      } else if (appState.phase != PipelineRunPhase.idle) {
        // Validation or preflight failed — stay on settings to show error.
        appState.removeListener(listener);
      }
    };
    appState.addListener(listener);
    unawaited(appState.runPipeline());
  }

  void _showPreview(BuildContext context, String command) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Command Preview'),
        content: SelectableText(command),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Right column panels ───────────────────────────────────────────────────────

class _ModelPanel extends StatelessWidget {
  const _ModelPanel({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final descriptions = [
      l10n.modelDescRecommended,
      l10n.modelDescFast,
      l10n.modelDescLegacy,
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.sectionNeuralModel, icon: Icons.psychology_outlined),
          const SizedBox(height: AppTokens.spacingMd),
          for (var i = 0; i < _kModelIds.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.spacingSm),
              child: _ModelCard(
                modelId: _kModelIds[i],
                description: descriptions[i],
                selected: appState.config.model == _kModelIds[i],
                onTap: () => appState.setModel(_kModelIds[i]),
              ),
            ),
          if (!_kModelIds.contains(appState.config.model))
            _ModelCard(
              modelId: appState.config.model,
              description: l10n.customModel,
              selected: true,
              onTap: () {},
            ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = appState.snapshot;
    final statusColor = switch (snapshot.phase) {
      PipelineRunPhase.idle => AppTokens.secondary,
      PipelineRunPhase.running => AppTokens.primary,
      PipelineRunPhase.success => AppTokens.success,
      PipelineRunPhase.failed => AppTokens.error,
    };
    final statusLabel = switch (snapshot.phase) {
      PipelineRunPhase.idle => l10n.statusReady,
      PipelineRunPhase.running => l10n.statusRunning,
      PipelineRunPhase.success => l10n.statusDone,
      PipelineRunPhase.failed => l10n.statusFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.currentProfile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTokens.onBackground.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(label: statusLabel, color: statusColor),
          ],
        ),
        const SizedBox(height: AppTokens.spacingMd),
        _ProfileRow(label: l10n.profileWorkers, value: '${appState.config.workers}'),
        _ProfileRow(label: l10n.profileRetries, value: '${appState.config.maxApiRetries}'),
        _ProfileRow(label: l10n.profileOutputImages, value: '${snapshot.outputImageCount}'),
        if (snapshot.error != null) ...[
          const Divider(height: 20),
          Text(
            snapshot.error!,
            style: const TextStyle(color: AppTokens.error, fontSize: 12),
          ),
        ],
        const Divider(height: 24),
        Text(
          l10n.tipsHeading,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTokens.onBackground.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tipsBody,
          style: TextStyle(
            fontSize: 12,
            color: AppTokens.onBackground.withValues(alpha: 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.onBackground.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTokens.primary.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTokens.onBackground.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.modelId,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String modelId;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppTokens.spacingSm),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.primaryContainer.withValues(alpha: 0.35)
              : AppTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTokens.primary.withValues(alpha: 0.45)
                : AppTokens.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppTokens.primary
                      : AppTokens.outlineVariant,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTokens.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTokens.primary
                          : AppTokens.onBackground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.onBackground.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTokens.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTokens.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.activeBadge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.success,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              value.round().toString(),
              style: const TextStyle(
                color: AppTokens.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppTokens.primary,
            inactiveTrackColor: AppTokens.surfaceBright,
            thumbColor: AppTokens.primary,
            overlayColor: AppTokens.primary.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minLabel,
              style: TextStyle(
                fontSize: 10,
                color: AppTokens.onBackground.withValues(alpha: 0.4),
              ),
            ),
            Text(
              maxLabel,
              style: TextStyle(
                fontSize: 10,
                color: AppTokens.onBackground.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineStepper extends StatelessWidget {
  const _InlineStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          width: 36,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTokens.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onPressed != null
              ? AppTokens.onBackground
              : AppTokens.onBackground.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.onBackground.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTokens.primary,
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }
}
