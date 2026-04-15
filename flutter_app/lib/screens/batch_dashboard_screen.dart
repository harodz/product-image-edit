import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_shell.dart';

class BatchDashboardScreen extends StatelessWidget {
  const BatchDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppShell(
      title: l10n.screenBatchDashboard,
      child: const _Content(),
    );
  }
}

// ── Content root ───────────────────────────────────────────────────────────────

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  bool _consoleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final snapshot = appState.snapshot;
    final hasFailures = snapshot.discoveredFailedCount > 0;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlobalStatusHeader(
          snapshot: snapshot,
          workers: appState.config.workers,
          onCancel: snapshot.phase == PipelineRunPhase.running
              ? appState.cancelPipeline
              : null,
        ),
        const SizedBox(height: AppTokens.spacingMd),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Hide the failure side-panel when the content area is too narrow
              // to show both the grid and the panel side by side.
              // Grid needs ~330px minimum (fixed cols + actions) even without the
              // latency column; panel + margin takes ~300px → threshold = 630px.
              // Round up to 730 to also safely fit inline retry buttons.
              const failurePanelWidth = 288.0;
              const failurePanelBreakpoint = 730.0;
              final showPanel =
                  hasFailures && constraints.maxWidth >= failurePanelBreakpoint;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ProcessingGrid(snapshot: snapshot, appState: appState),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: showPanel ? failurePanelWidth : 0,
                    child: showPanel
                        ? _FailureSidePanel(snapshot: snapshot, appState: appState)
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppTokens.spacingMd),
        _CollapsibleConsole(
          logLines: snapshot.logLines,
          expanded: _consoleExpanded,
          onToggle: () => setState(() => _consoleExpanded = !_consoleExpanded),
        ),
      ],
    );

    if (snapshot.phase == PipelineRunPhase.success) {
      body = Stack(
        children: [
          body,
          _FinalityOverlay(snapshot: snapshot, appState: appState),
        ],
      );
    }

    return body;
  }
}

// ── Global Status Header ───────────────────────────────────────────────────────

class _GlobalStatusHeader extends StatelessWidget {
  const _GlobalStatusHeader({
    required this.snapshot,
    required this.workers,
    this.onCancel,
  });

  final PipelineRunSnapshot snapshot;
  final int workers;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final done = snapshot.discoveredDoneCount;
    final total = snapshot.totalDiscoveredCount > 0
        ? snapshot.totalDiscoveredCount
        : (done + snapshot.discoveredFailedCount);
    final geminiActive = snapshot.imageJobs.values
        .where((j) => j.geminiStage == GeminiStage.processing)
        .length;
    final cleanupActive = snapshot.imageJobs.values
        .where((j) => j.cleanupStage == CleanupStage.processing)
        .length;
    final workersActive = geminiActive + cleanupActive;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spacingMd),
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(
          color: AppTokens.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar + heartbeat row
          Row(
            children: [
              Expanded(
                child:                 _DualStageProgressBar(
                  done: done,
                  total: total,
                  geminiActive: geminiActive,
                  cleanupActive: cleanupActive,
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: AppTokens.spacingMd),
              _HeartbeatMonitor(
                workersActive: workersActive,
                workersTotal: workers,
                is429Backoff: snapshot.is429Backoff,
                backoffSeconds: snapshot.backoffSecondsRemaining,
                backoffReason: snapshot.backoffReason,
                l10n: l10n,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacingMd),
          // Metric tiles + cancel button
          Row(
            children: [
              _MetricTile(
                label: l10n.metricEta,
                value: snapshot.eta != null
                    ? _formatDuration(context, snapshot.eta!)
                    : l10n.emDash,
                icon: Icons.timer_outlined,
              ),
              const SizedBox(width: AppTokens.spacingSm),
              _MetricTile(
                label: l10n.metricThroughput,
                value: snapshot.throughputIPM != null
                    ? '${snapshot.throughputIPM!.toStringAsFixed(1)}${l10n.perMinute}'
                    : l10n.emDash,
                icon: Icons.speed_outlined,
              ),
              const SizedBox(width: AppTokens.spacingSm),
              _MetricTile(
                label: l10n.metricSuccessRate,
                value: snapshot.phase == PipelineRunPhase.idle
                    ? l10n.emDash
                    : '${(snapshot.successRate * 100).toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                valueColor: snapshot.successRate >= 0.9
                    ? AppTokens.success
                    : snapshot.successRate >= 0.7
                        ? AppTokens.primary
                        : AppTokens.error,
              ),
              if (onCancel != null) ...[
                const Spacer(),
                _CancelButton(onCancel: onCancel!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(BuildContext context, Duration d) {
    final l10n = AppLocalizations.of(context)!;
    if (d.inHours > 0) {
      return l10n.durationHm(d.inHours, d.inMinutes.remainder(60));
    }
    if (d.inMinutes > 0) {
      return l10n.durationMs(d.inMinutes, d.inSeconds.remainder(60));
    }
    return l10n.durationS(d.inSeconds);
  }
}

// ── Dual-stage progress bar ────────────────────────────────────────────────────

class _DualStageProgressBar extends StatelessWidget {
  const _DualStageProgressBar({
    required this.done,
    required this.total,
    required this.geminiActive,
    required this.cleanupActive,
    required this.l10n,
  });

  final int done;
  final int total;
  final int geminiActive;
  final int cleanupActive;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final progressLabel =
        total > 0 ? l10n.imagesProgressTotal(done, total) : l10n.imagesProgressNone(done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                progressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.onBackground,
                ),
              ),
            ),
            if (geminiActive > 0 || cleanupActive > 0)
              Flexible(
                fit: FlexFit.loose,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    if (geminiActive > 0)
                      _SegmentLabel(
                        color: AppTokens.secondary,
                        label: l10n.geminiActiveLabel(geminiActive),
                      ),
                    if (cleanupActive > 0) ...[
                      const SizedBox(width: 8),
                      _SegmentLabel(
                        color: AppTokens.tertiary,
                        label: l10n.cleanupActiveLabel(cleanupActive),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 8,
          child: CustomPaint(
            painter: _ProgressBarPainter(
              done: done,
              total: total,
              geminiActive: geminiActive,
              cleanupActive: cleanupActive,
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTokens.onBackground.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  const _ProgressBarPainter({
    required this.done,
    required this.total,
    required this.geminiActive,
    required this.cleanupActive,
  });

  final int done;
  final int total;
  final int geminiActive;
  final int cleanupActive;

  @override
  void paint(Canvas canvas, Size size) {
    const r = Radius.circular(4);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, r);

    // Background
    canvas.drawRRect(
      rrect,
      Paint()..color = AppTokens.surfaceHigh,
    );

    if (total <= 0) return;

    double x = 0;

    double segW(int count) => (count / total) * size.width;

    // Done segment
    final doneW = segW(done).clamp(0.0, size.width);
    if (doneW > 0) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(x, 0, x + doneW, size.height,
            topLeft: r, bottomLeft: r,
            topRight: doneW >= size.width ? r : Radius.zero,
            bottomRight: doneW >= size.width ? r : Radius.zero),
        Paint()..color = AppTokens.onBackground.withValues(alpha: 0.2),
      );
      x += doneW;
    }

    // Gemini active (purple)
    final gemW = segW(geminiActive).clamp(0.0, size.width - x);
    if (gemW > 0) {
      canvas.drawRect(Rect.fromLTWH(x, 0, gemW, size.height),
          Paint()..color = AppTokens.secondary);
      x += gemW;
    }

    // Cleanup active (teal)
    final cleanW = segW(cleanupActive).clamp(0.0, size.width - x);
    if (cleanW > 0) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(x, 0, x + cleanW, size.height,
            topRight: r, bottomRight: r,
            topLeft: Radius.zero, bottomLeft: Radius.zero),
        Paint()..color = AppTokens.tertiary,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter old) =>
      old.done != done ||
      old.total != total ||
      old.geminiActive != geminiActive ||
      old.cleanupActive != cleanupActive;
}

// ── Heartbeat monitor ──────────────────────────────────────────────────────────

class _HeartbeatMonitor extends StatefulWidget {
  const _HeartbeatMonitor({
    required this.workersActive,
    required this.workersTotal,
    required this.is429Backoff,
    required this.backoffSeconds,
    required this.backoffReason,
    required this.l10n,
  });

  final int workersActive;
  final int workersTotal;
  final bool is429Backoff;
  final int backoffSeconds;
  final String backoffReason;
  final AppLocalizations l10n;

  @override
  State<_HeartbeatMonitor> createState() => _HeartbeatMonitorState();
}

class _HeartbeatMonitorState extends State<_HeartbeatMonitor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_HeartbeatMonitor old) {
    super.didUpdateWidget(old);
    if (widget.is429Backoff && !old.is429Backoff) _ctrl.stop();
    if (!widget.is429Backoff && old.is429Backoff) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.is429Backoff ? Colors.amber : AppTokens.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: widget.is429Backoff ? const AlwaysStoppedAnimation(1.0) : _scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.is429Backoff
                  ? widget.l10n.backoffSeconds(widget.backoffSeconds)
                  : widget.l10n.workersActiveLabel(
                      widget.workersActive,
                      widget.workersTotal,
                    ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.is429Backoff
                    ? Colors.amber
                    : AppTokens.onBackground.withValues(alpha: 0.85),
              ),
            ),
            if (widget.is429Backoff)
              Text(
                widget.backoffReason == 'server_error'
                    ? widget.l10n.serverErrorWaiting
                    : widget.l10n.rateLimitWaiting,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Metric tile ────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacingSm,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTokens.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTokens.onBackground.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppTokens.onBackground,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: AppTokens.onBackground.withValues(alpha: 0.45),
                    ),
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

// ── Processing grid ────────────────────────────────────────────────────────────

class _ProcessingGrid extends StatelessWidget {
  const _ProcessingGrid({
    required this.snapshot,
    required this.appState,
  });

  final PipelineRunSnapshot snapshot;
  final AppState appState;

  // Below this content width hide the latency column to avoid overflow.
  // Must be > max fixed-cols-with-retry (400px) + padding (24px) = 424px → use 450.
  static const _kHideLatencyBreakpoint = 450.0;

  @override
  Widget build(BuildContext context) {
    final jobs = snapshot.imageJobs.values.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLatency = constraints.maxWidth >= _kHideLatencyBreakpoint;
        return Container(
          decoration: BoxDecoration(
            color: AppTokens.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _GridHeader(showLatency: showLatency),
              const Divider(height: 1, color: Color(0xFF1E2530)),
              // Body
              Expanded(
                child: jobs.isEmpty
                    ? _EmptyState(phase: snapshot.phase)
                    : ListView.builder(
                        itemCount: jobs.length,
                        itemExtent: 56,
                        itemBuilder: (context, i) {
                          return _ImageJobRow(
                            job: jobs[i],
                            logLines: snapshot.logLines,
                            onRetry: appState.retryFailed,
                            showLatency: showLatency,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.showLatency});
  final bool showLatency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Color(0xFF6F7683),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(l10n.gridFilename, style: labelStyle),
          ),
          SizedBox(
            width: 100,
            child: Text(l10n.gridGemini, style: labelStyle),
          ),
          SizedBox(
            width: 100,
            child: Text(l10n.gridCleanup, style: labelStyle),
          ),
          if (showLatency)
            SizedBox(
              width: 72,
              child: Text(l10n.gridLatency, style: labelStyle),
            ),
          Text(l10n.gridActions, style: labelStyle),
        ],
      ),
    );
  }
}

// ── Image job row ──────────────────────────────────────────────────────────────

class _ImageJobRow extends StatefulWidget {
  const _ImageJobRow({
    required this.job,
    required this.logLines,
    required this.onRetry,
    required this.showLatency,
  });

  final ImageJobState job;
  final List<String> logLines;
  final VoidCallback onRetry;
  final bool showLatency;

  @override
  State<_ImageJobRow> createState() => _ImageJobRowState();
}

class _ImageJobRowState extends State<_ImageJobRow> {
  OverlayEntry? _thumbOverlay;

  void _showThumbOverlay(BuildContext context, RenderBox box) {
    final path = widget.job.inputPath;
    if (path == null || !File(path).existsSync()) return;
    final offset = box.localToGlobal(Offset.zero);
    _thumbOverlay = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx + 50,
        top: (offset.dy - 80).clamp(8.0, double.infinity),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16)],
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_thumbOverlay!);
  }

  void _hideThumbOverlay() {
    _thumbOverlay?.remove();
    _thumbOverlay = null;
  }

  @override
  void dispose() {
    _hideThumbOverlay();
    super.dispose();
  }

  void _showLogs(BuildContext context) {
    final filtered = widget.logLines
        .where((l) => l.contains(widget.job.fileName))
        .toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _LogDialog(
        fileName: widget.job.fileName,
        lines: filtered,
        l10n: AppLocalizations.of(dialogContext)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final job = widget.job;
    final isProcessingGemini = job.geminiStage == GeminiStage.processing;
    final isFailed = job.geminiStage == GeminiStage.failed ||
        job.geminiStage == GeminiStage.safetyBlocked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.outlineVariant.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          MouseRegion(
            onEnter: (_) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) _showThumbOverlay(context, box);
            },
            onExit: (_) => _hideThumbOverlay(),
            child: _Thumbnail(path: job.inputPath),
          ),
          const SizedBox(width: 8),
          // Filename — Expanded so it fills remaining space and never overflows.
          Expanded(
            child: Text(
              job.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          // Gemini stage
          SizedBox(
            width: 100,
            child: isProcessingGemini
                ? const _SpinningIcon(icon: Icons.auto_awesome, color: AppTokens.secondary)
                : _stageIcon(job.geminiStage),
          ),
          // Cleanup stage
          SizedBox(
            width: 100,
            child: _cleanupIcon(job.cleanupStage),
          ),
          // Latency — hidden when grid is too narrow.
          if (widget.showLatency)
            SizedBox(
              width: 72,
              child: Text(
                job.latencyMs != null
                    ? '${(job.latencyMs! / 1000).toStringAsFixed(1)}s'
                    : AppLocalizations.of(context)!.emDash,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTokens.onBackground.withValues(alpha: 0.6),
                ),
              ),
            ),
          // Actions
          TextButton(
            onPressed: () => _showLogs(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.logs, style: const TextStyle(fontSize: 11)),
          ),
          if (isFailed) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTokens.error,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.retry, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageIcon(GeminiStage stage) {
    switch (stage) {
      case GeminiStage.done:
        return const Icon(Icons.check_circle_rounded, size: 16, color: AppTokens.success);
      case GeminiStage.failed:
        return const Icon(Icons.error_rounded, size: 16, color: AppTokens.error);
      case GeminiStage.safetyBlocked:
        return const Icon(Icons.block_rounded, size: 16, color: Colors.amber);
      case GeminiStage.processing:
        return const _SpinningIcon(icon: Icons.auto_awesome, color: AppTokens.secondary);
      case GeminiStage.pending:
        return Icon(Icons.radio_button_unchecked,
            size: 16, color: AppTokens.onBackground.withValues(alpha: 0.25));
    }
  }

  Widget _cleanupIcon(CleanupStage stage) {
    switch (stage) {
      case CleanupStage.done:
        return const Icon(Icons.check_circle_rounded, size: 16, color: AppTokens.success);
      case CleanupStage.processing:
        return const Icon(Icons.auto_delete_outlined, size: 16, color: AppTokens.tertiary);
      case CleanupStage.pending:
        return Icon(Icons.radio_button_unchecked,
            size: 16, color: AppTokens.onBackground.withValues(alpha: 0.25));
    }
  }
}

// ── Thumbnail ──────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTokens.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.hardEdge,
      child: path != null && File(path!).existsSync()
          ? Image.file(File(path!), fit: BoxFit.cover, width: 40, height: 40)
          : Icon(
              Icons.image_outlined,
              size: 18,
              color: AppTokens.onBackground.withValues(alpha: 0.2),
            ),
    );
  }
}

// ── Spinning icon ──────────────────────────────────────────────────────────────

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(widget.icon, size: 16, color: widget.color),
    );
  }
}

// ── Log dialog ─────────────────────────────────────────────────────────────────

class _LogDialog extends StatelessWidget {
  const _LogDialog({
    required this.fileName,
    required this.lines,
    required this.l10n,
  });
  final String fileName;
  final List<String> lines;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTokens.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 360, minHeight: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTokens.spacingMd),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: AppTokens.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.logsForFile(fileName),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTokens.onBackground.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E2530)),
            Expanded(
              child: lines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noLogEntriesForFile,
                        style: TextStyle(
                          color: AppTokens.onBackground.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTokens.spacingMd),
                      itemCount: lines.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          lines[i],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppTokens.onBackground,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.phase});
  final PipelineRunPhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRunning = phase == PipelineRunPhase.running;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTokens.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isRunning ? Icons.hourglass_top_rounded : Icons.upload_file_outlined,
              size: 28,
              color: AppTokens.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppTokens.spacingMd),
          Text(
            isRunning ? l10n.emptyWaitingFirstImage : l10n.emptyNoActiveRun,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            isRunning ? l10n.emptyWaitingFirstImageSub : l10n.emptyNoActiveRunSub,
            style: TextStyle(
              fontSize: 12,
              color: AppTokens.onBackground.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Failure side panel ─────────────────────────────────────────────────────────

class _FailureSidePanel extends StatelessWidget {
  const _FailureSidePanel({
    required this.snapshot,
    required this.appState,
  });

  final PipelineRunSnapshot snapshot;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jobs = snapshot.imageJobs.values;
    final safetyCount =
        jobs.where((j) => j.errorType == ImageErrorType.safetyFilter).length;
    final quotaCount =
        jobs.where((j) => j.errorType == ImageErrorType.quota).length;
    final apiCount =
        jobs.where((j) => j.errorType == ImageErrorType.apiError).length;

    return Container(
      margin: const EdgeInsets.only(left: AppTokens.spacingSm),
      decoration: BoxDecoration(
        color: AppTokens.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: AppTokens.error),
                const SizedBox(width: 6),
                Text(
                  l10n.failuresHeading,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTokens.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${snapshot.discoveredFailedCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTokens.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E2530)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error group cards
                  if (safetyCount > 0)
                    _ErrorGroupCard(
                      icon: Icons.shield_outlined,
                      color: Colors.amber,
                      label: l10n.errorGroupSafetyFilter,
                      count: safetyCount,
                    ),
                  if (quotaCount > 0) ...[
                    const SizedBox(height: 8),
                    _ErrorGroupCard(
                      icon: Icons.speed_outlined,
                      color: AppTokens.error,
                      label: l10n.errorGroupRateLimit,
                      count: quotaCount,
                    ),
                  ],
                  if (apiCount > 0) ...[
                    const SizedBox(height: 8),
                    _ErrorGroupCard(
                      icon: Icons.error_outline_rounded,
                      color: AppTokens.secondary,
                      label: l10n.errorGroupApiError,
                      count: apiCount,
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFF1E2530)),
                  const SizedBox(height: 14),
                  // Action buttons
                  _PanelButton(
                    icon: Icons.refresh_rounded,
                    label: l10n.retryAllFailed,
                    color: AppTokens.primary,
                    onPressed: snapshot.canRetryFailed ? appState.retryFailed : null,
                  ),
                  const SizedBox(height: 8),
                  _PanelButton(
                    icon: Icons.folder_copy_outlined,
                    label: l10n.openOutputFolder,
                    color: AppTokens.tertiary,
                    onPressed: appState.openOutputFolder,
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFF1E2530)),
                  const SizedBox(height: 12),
                  // Workers slider
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 13, color: AppTokens.onBackground),
                      const SizedBox(width: 6),
                      Text(
                        l10n.workersLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        '${appState.config.workers}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.primary,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: AppTokens.primary,
                      inactiveTrackColor: AppTokens.outlineVariant.withValues(alpha: 0.3),
                      thumbColor: AppTokens.primary,
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: appState.config.workers.clamp(1, 64).toDouble(),
                      min: 1,
                      max: 64,
                      divisions: 63,
                      onChanged: (v) => appState.setWorkers(v.round()),
                    ),
                  ),
                  Text(
                    l10n.takesEffectNextRetry,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTokens.onBackground.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorGroupCard extends StatelessWidget {
  const _ErrorGroupCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

// ── Cancel button ─────────────────────────────────────────────────────────────

class _CancelButton extends StatefulWidget {
  const _CancelButton({required this.onCancel});
  final Future<void> Function() onCancel;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await widget.onCancel();
                if (mounted) setState(() => _busy = false);
              },
        icon: _busy
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : const Icon(Icons.stop_circle_outlined, size: 13),
        label: Text(
          _busy ? l10n.cancellingLabel : l10n.cancelPipeline,
          style: const TextStyle(fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.error,
          side: BorderSide(color: AppTokens.error.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

// ── Collapsible console ────────────────────────────────────────────────────────

class _CollapsibleConsole extends StatelessWidget {
  const _CollapsibleConsole({
    required this.logLines,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> logLines;
  final bool expanded;
  final VoidCallback onToggle;

  static const _errorKeywords = ['RETRYING', '429', 'Error:', 'Backoff', 'backoff'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final criticalCount =
        logLines.where((l) => _errorKeywords.any((k) => l.contains(k))).length;

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spacingMd,
                vertical: 10,
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, size: 14, color: AppTokens.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.consoleHeading,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  if (logLines.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceHigh,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${logLines.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTokens.onBackground.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (criticalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTokens.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        l10n.consoleErrorCount(criticalCount),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTokens.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_more : Icons.expand_less,
                    size: 16,
                    color: AppTokens.onBackground.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          // Body (animated)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: expanded ? 180 : 0,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: Color(0xFF1E2530)),
                      Expanded(
                        child: logLines.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.noOutputYet,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTokens.onBackground.withValues(alpha: 0.4),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                reverse: true,
                                itemCount: logLines.length,
                                itemBuilder: (_, i) {
                                  final line = logLines[logLines.length - 1 - i];
                                  final isError = _errorKeywords.any((k) => line.contains(k));
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: isError
                                            ? AppTokens.error
                                            : AppTokens.onBackground.withValues(alpha: 0.75),
                                        height: 1.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Finality overlay ───────────────────────────────────────────────────────────

class _FinalityOverlay extends StatelessWidget {
  const _FinalityOverlay({
    required this.snapshot,
    required this.appState,
  });

  final PipelineRunSnapshot snapshot;
  final AppState appState;

  static String _formatDuration(BuildContext context, Duration d) {
    final l10n = AppLocalizations.of(context)!;
    if (d.inHours > 0) {
      return l10n.durationHms(
        d.inHours,
        d.inMinutes.remainder(60),
        d.inSeconds.remainder(60),
      );
    }
    if (d.inMinutes > 0) {
      return l10n.durationMs(d.inMinutes, d.inSeconds.remainder(60));
    }
    return l10n.durationS(d.inSeconds);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 0) return '−${_formatBytes(-bytes)}';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final duration = snapshot.startedAt != null && snapshot.finishedAt != null
        ? snapshot.finishedAt!.difference(snapshot.startedAt!)
        : null;
    final total = snapshot.totalDiscoveredCount > 0
        ? snapshot.totalDiscoveredCount
        : snapshot.discoveredDoneCount;
    final durationPart = duration != null
        ? l10n.durationPartIn(_formatDuration(context, duration))
        : '';

    return Positioned.fill(
      child: Container(
        color: AppTokens.background.withValues(alpha: 0.8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
            padding: const EdgeInsets.all(AppTokens.spacingXl),
            decoration: BoxDecoration(
              color: AppTokens.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTokens.success.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppTokens.success.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTokens.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 30, color: AppTokens.success),
                ),
                const SizedBox(height: AppTokens.spacingMd),
                Text(
                  l10n.batchComplete,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.onBackground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.batchCompleteSubtitle(
                    snapshot.discoveredDoneCount,
                    total,
                    durationPart,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTokens.onBackground.withValues(alpha: 0.65),
                  ),
                ),
                if (snapshot.spaceSavedBytes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTokens.tertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compress_rounded,
                            size: 13, color: AppTokens.tertiary),
                        const SizedBox(width: 6),
                        Text(
                          l10n.spaceSaved(_formatBytes(snapshot.spaceSavedBytes!)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTokens.tertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.spacingXl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: appState.openOutputFolder,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(l10n.openOutputFolder),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTokens.tertiary,
                          side: BorderSide(color: AppTokens.tertiary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spacingMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRouter.pipelineSettingsRoute,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l10n.startNewBatch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primaryContainer,
                          foregroundColor: AppTokens.onBackground,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ), // ConstrainedBox
        ),
      ),
    );
  }
}

