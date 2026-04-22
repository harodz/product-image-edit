import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../services/pipeline_runner.dart';
import '../utils/log_redaction.dart';

enum PipelineRunPhase { idle, running, success, failed }
enum ReviewStatus { approved, needsEdit, rejected, unreviewed }
enum GeminiStage { pending, processing, done, failed, safetyBlocked }
enum CleanupStage { pending, processing, done }
enum ImageErrorType { safetyFilter, quota, apiError }

const _kPipelineStateFilename = '_pipeline_image_state.json';

const _kReviewStrings = {'approved', 'needsEdit', 'rejected', 'unreviewed'};
const _kGeminiStrings = {
  'pending',
  'processing',
  'done',
  'failed',
  'safetyBlocked',
};
const _kCleanupStrings = {'pending', 'processing', 'done'};

class ImageJobState {
  ImageJobState({required this.fileName, this.inputPath});
  final String fileName;
  final String? inputPath;
  GeminiStage geminiStage = GeminiStage.pending;
  CleanupStage cleanupStage = CleanupStage.pending;
  DateTime? processingStartedAt;
  int? latencyMs;
  String? errorMessage;
  ImageErrorType? errorType;
}

class PipelineConfig {
  String inputDir = '';
  String outputDir = '';
  String prompt =
      'Clean it up and remove customer logo for a product shot. White background only. Professional Lighting.';
  String model = 'gemini-3.1-flash-image-preview';
  int workers = 10;
  int maxApiRetries = 6;
  bool keepRaw = false;
  bool failFast = false;
  bool useResponseModalities = false;
  bool copyFailed = false;
  bool noProgress = false;
  String? aspectRatio;
  int? outputDimension;
  bool outputLandscape = true;

  (int, int)? get computedOutputSize {
    final dim = outputDimension;
    if (dim == null || dim <= 0) return null;
    final ar = aspectRatio;
    if (ar == null || ar.isEmpty) return (dim, dim);
    final parts = ar.split(':');
    if (parts.length != 2) return (dim, dim);
    final rw = int.tryParse(parts[0]);
    final rh = int.tryParse(parts[1]);
    if (rw == null || rh == null || rw <= 0 || rh <= 0) return (dim, dim);
    final longSide = dim;
    final shortSide = (longSide * (rw < rh ? rw : rh)) ~/ (rw > rh ? rw : rh);
    final w = rw >= rh ? longSide : shortSide;
    final h = rw >= rh ? shortSide : longSide;
    return outputLandscape ? (w, h) : (h, w);
  }

  List<String> validate() {
    final errors = <String>[];
    if (inputDir.trim().isEmpty) {
      errors.add('请输入输入目录。');
    } else if (!Directory(inputDir).existsSync()) {
      errors.add('输入目录不存在。');
    }
    if (outputDir.trim().isEmpty) {
      errors.add('请输入输出目录。');
    }
    if (workers < 1) {
      errors.add('并发数至少为 1。');
    }
    if (maxApiRetries < 0) {
      errors.add('重试次数须为 0 或更大。');
    }
    if (outputDimension != null) {
      final d = outputDimension!;
      if (d <= 0 || d > 8192) {
        errors.add('输出尺寸须在 1..8192 之间。');
      }
    }
    return errors;
  }
}

class PipelineRunSnapshot {
  const PipelineRunSnapshot({
    required this.phase,
    required this.startedAt,
    required this.finishedAt,
    required this.exitCode,
    required this.commandPreview,
    required this.logLines,
    required this.error,
    required this.discoveredFailedCount,
    required this.discoveredDoneCount,
    required this.totalDiscoveredCount,
    required this.lastRetryCommand,
    required this.canRetryFailed,
    required this.reviewItems,
    required this.outputImageCount,
    required this.imageJobs,
    required this.is429Backoff,
    required this.backoffSecondsRemaining,
    required this.backoffReason,
    required this.throughputIPM,
    required this.eta,
    required this.successRate,
    required this.spaceSavedBytes,
  });

  final PipelineRunPhase phase;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final String commandPreview;
  final List<String> logLines;
  final String? error;
  final int discoveredFailedCount;
  final int discoveredDoneCount;
  final int totalDiscoveredCount;
  final String? lastRetryCommand;
  final bool canRetryFailed;
  final List<OutputReviewItem> reviewItems;
  final int outputImageCount;
  final Map<String, ImageJobState> imageJobs;
  final bool is429Backoff;
  final int backoffSecondsRemaining;
  final String backoffReason;
  final double? throughputIPM;
  final Duration? eta;
  final double successRate;
  final int? spaceSavedBytes;
}

class OutputReviewItem {
  const OutputReviewItem({
    required this.path,
    required this.fileName,
    required this.status,
  });

  final String path;
  final String fileName;
  final ReviewStatus status;
}

class AppState extends ChangeNotifier {
  AppState(
    this._runner, {
    required this.applicationSupportPath,
  }) : apiKeyController = TextEditingController() {
    apiKeyController.addListener(_onApiKeyTextChanged);
    config.outputDir = '$applicationSupportPath/output';
    unawaited(_bootstrap());
  }

  final PipelineRunner _runner;
  final String applicationSupportPath;
  final TextEditingController apiKeyController;
  final PipelineConfig config = PipelineConfig();

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  Timer? _apiKeyDebounce;
  Timer? _galleryPollTimer;
  bool _apiKeyHydrating = false;
  String _lastWrittenApiKey = '';
  DateTime? _apiKeySavedAt;

  DateTime? get apiKeyLastPersistedAt => _apiKeySavedAt;

  /// Short message for input path issues (e.g. staging a dropped image).
  String? _inputNotice;
  String? get inputNotice => _inputNotice;

  PipelineRunPhase _phase = PipelineRunPhase.idle;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  int? _exitCode;
  String? _error;
  final List<String> _logLines = <String>[];
  int _discoveredFailedCount = 0;
  int _discoveredDoneCount = 0;
  int _totalDiscoveredCount = 0;
  String? _lastRetryCommand;
  List<String>? _lastRetryArgv;
  final List<OutputReviewItem> _reviewItems = <OutputReviewItem>[];
  final Map<String, ImageJobState> _imageJobs = {};
  bool _is429Backoff = false;
  int _backoffSecondsRemaining = 0;
  String _backoffReason = 'rate_limit';
  Timer? _backoffTimer;
  int? _spaceSavedBytes;

  bool get isRunning => _phase == PipelineRunPhase.running;
  PipelineRunPhase get phase => _phase;
  String? get error => _error;
  String get commandPreview => _runner.buildCommandPreview(config);

  PipelineRunSnapshot get snapshot {
    final elapsed = _startedAt != null
        ? (_finishedAt ?? DateTime.now()).difference(_startedAt!)
        : null;
    final elapsedMinutes = (elapsed?.inSeconds ?? 0) / 60.0;
    final done = _discoveredDoneCount;
    final failed = _discoveredFailedCount;

    double? throughputIPM;
    if (elapsed != null && elapsed.inSeconds >= 5 && done > 0) {
      throughputIPM = done / elapsedMinutes;
    }

    Duration? eta;
    if (elapsed != null && done > 0 && _totalDiscoveredCount > done) {
      final remaining = _totalDiscoveredCount - done;
      final secondsPerImage = elapsed.inSeconds / done;
      eta = Duration(seconds: (remaining * secondsPerImage).round());
    }

    final total = done + failed;
    final successRate = total > 0 ? done / total : 0.0;

    return PipelineRunSnapshot(
      phase: _phase,
      startedAt: _startedAt,
      finishedAt: _finishedAt,
      exitCode: _exitCode,
      commandPreview: commandPreview,
      logLines: List<String>.unmodifiable(_logLines),
      error: _error,
      discoveredFailedCount: failed,
      discoveredDoneCount: done,
      totalDiscoveredCount: _totalDiscoveredCount,
      lastRetryCommand: _lastRetryCommand,
      canRetryFailed: _lastRetryArgv != null && _lastRetryArgv!.isNotEmpty,
      reviewItems: List<OutputReviewItem>.unmodifiable(_reviewItems),
      outputImageCount: _reviewItems.length,
      imageJobs: Map.unmodifiable(_imageJobs),
      is429Backoff: _is429Backoff,
      backoffSecondsRemaining: _backoffSecondsRemaining,
      backoffReason: _backoffReason,
      throughputIPM: throughputIPM,
      eta: eta,
      successRate: successRate,
      spaceSavedBytes: _spaceSavedBytes,
    );
  }

  void setInputDir(String value) {
    _inputNotice = null;
    config.inputDir = value;
    unawaited(_saveSettings());
    unawaited(reloadRunnableJobsFromDisk());
    notifyListeners();
  }

  /// Drop, browse, or window chrome: folder path or a single image file (staged under app support).
  Future<void> applyDroppedInputPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final type = FileSystemEntity.typeSync(trimmed);
    if (type == FileSystemEntityType.notFound) {
      setInputDir(trimmed);
      return;
    }
    if (type == FileSystemEntityType.directory) {
      _inputNotice = null;
      setInputDir(trimmed);
      return;
    }
    if (type == FileSystemEntityType.file) {
      final lower = trimmed.toLowerCase();
      final dot = lower.lastIndexOf('.');
      final ext = dot >= 0 ? lower.substring(dot) : '';
      if (_imageExtensions.contains(ext)) {
        await _stageSingleImageAndSetInput(trimmed);
        return;
      }
      final parent = File(trimmed).parent.path;
      if (Directory(parent).existsSync()) {
        setInputDir(parent);
      }
      return;
    }
    setInputDir(trimmed);
  }

  Future<void> _stageSingleImageAndSetInput(String filePath) async {
    final stage = Directory('$applicationSupportPath/dropped_single');
    try {
      if (stage.existsSync()) {
        for (final e in stage.listSync(followLinks: false)) {
          try {
            e.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      }
      await stage.create(recursive: true);
      final name = filePath.split(Platform.pathSeparator).last;
      final dest = File('${stage.path}${Platform.pathSeparator}$name');
      await File(filePath).copy(dest.path);
      _inputNotice = null;
      config.inputDir = stage.path;
      await _saveSettings();
      notifyListeners();
    } on Exception catch (e) {
      _inputNotice = '无法暂存图片：$e';
      notifyListeners();
    }
  }

  /// File-picker selection of one or more image files; stages all into dropped_single/.
  Future<void> applyImageFilesPicked(List<String> paths) async {
    final filtered = paths.where((p) {
      final ext = p.toLowerCase().lastIndexOf('.');
      return ext >= 0 && _imageExtensions.contains(p.toLowerCase().substring(ext));
    }).toList();
    if (filtered.isEmpty) return;
    if (filtered.length == 1) {
      await _stageSingleImageAndSetInput(filtered.first);
      return;
    }
    final stage = Directory('$applicationSupportPath/dropped_single');
    try {
      if (stage.existsSync()) {
        for (final e in stage.listSync(followLinks: false)) {
          try {
            e.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      }
      await stage.create(recursive: true);
      for (final filePath in filtered) {
        final name = filePath.split(Platform.pathSeparator).last;
        final dest = File('${stage.path}${Platform.pathSeparator}$name');
        await File(filePath).copy(dest.path);
      }
      _inputNotice = null;
      config.inputDir = stage.path;
      await _saveSettings();
      notifyListeners();
    } on Exception catch (e) {
      _inputNotice = '无法暂存图片：$e';
      notifyListeners();
    }
  }

  void _onApiKeyTextChanged() {
    if (_apiKeyHydrating) {
      return;
    }
    _apiKeyDebounce?.cancel();
    _apiKeyDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_persistApiKeyIfChanged());
    });
  }

  /// Call when the API key field loses focus (immediate save).
  Future<void> flushApiKeyToDisk() async {
    _apiKeyDebounce?.cancel();
    await _persistApiKeyIfChanged();
  }

  void setOutputDir(String value) {
    config.outputDir = value;
    unawaited(refreshOutputReviews());
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setPrompt(String value) {
    config.prompt = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setModel(String value) {
    config.model = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setWorkers(int value) {
    config.workers = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setRetries(int value) {
    config.maxApiRetries = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setFlagKeepRaw(bool value) {
    config.keepRaw = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setFlagFailFast(bool value) {
    config.failFast = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setFlagUseResponseModalities(bool value) {
    config.useResponseModalities = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setFlagCopyFailed(bool value) {
    config.copyFailed = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setFlagNoProgress(bool value) {
    config.noProgress = value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setAspectRatio(String? value) {
    config.aspectRatio = (value == null || value.isEmpty) ? null : value;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void setOutputDimension(int? value) {
    config.outputDimension = (value != null && value > 0) ? value : null;
    unawaited(_saveSettings());
    notifyListeners();
  }

  void toggleOutputOrientation() {
    config.outputLandscape = !config.outputLandscape;
    unawaited(_saveSettings());
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    await _loadSavedState();
    await reloadRunnableJobsFromDisk();
    unawaited(refreshOutputReviews());
    await _hydrateApiKeyField();
    notifyListeners();
  }

  Future<List<String>> runPreflightChecks() async {
    return _runner.runPreflightChecks(config);
  }

  Future<void> _hydrateApiKeyField() async {
    _apiKeyHydrating = true;
    try {
      final k = await _runner.loadExistingApiKeyForDisplay();
      if (k != null && k.isNotEmpty) {
        apiKeyController.text = k;
        _lastWrittenApiKey = k;
      }
    } finally {
      _apiKeyHydrating = false;
    }
    notifyListeners();
  }

  Future<void> _persistApiKeyIfChanged() async {
    final t = apiKeyController.text.trim();
    if (t.isEmpty) {
      return;
    }
    if (t == _lastWrittenApiKey) {
      return;
    }
    try {
      await _runner.writeGeminiApiKey(t);
      _lastWrittenApiKey = t;
      _apiKeySavedAt = DateTime.now();
      notifyListeners();
    } on Object {
      // Avoid surfacing key material; user can retry from API tab.
    }
  }

  /// Persists non-empty editor text so the subprocess sees it (same as Save).
  Future<void> _syncApiKeyToAppSupportBeforeRun() async {
    _apiKeyDebounce?.cancel();
    final t = apiKeyController.text.trim();
    if (t.isEmpty) {
      return;
    }
    await _runner.writeGeminiApiKey(t);
    _lastWrittenApiKey = t;
    _apiKeySavedAt = DateTime.now();
  }

  /// Writes the current field to `applicationSupportPath/.env`. Empty clears stored keys there.
  Future<String?> saveApiKeyToAppSupport() async {
    _apiKeyDebounce?.cancel();
    try {
      await _runner.writeGeminiApiKey(apiKeyController.text.trim());
      _lastWrittenApiKey = apiKeyController.text.trim();
      _apiKeySavedAt = DateTime.now();
      notifyListeners();
      return null;
    } on Object catch (e) {
      return e.toString();
    }
  }

  @override
  void dispose() {
    _apiKeyDebounce?.cancel();
    _galleryPollTimer?.cancel();
    _backoffTimer?.cancel();
    apiKeyController.removeListener(_onApiKeyTextChanged);
    apiKeyController.dispose();
    super.dispose();
  }

  Future<void> runPipeline() async {
    final errors = config.validate();
    if (errors.isNotEmpty) {
      _phase = PipelineRunPhase.failed;
      _error = errors.join('\n');
      notifyListeners();
      return;
    }

    try {
      await _syncApiKeyToAppSupportBeforeRun();
    } on Object catch (e) {
      _phase = PipelineRunPhase.failed;
      _error = '无法保存 API 密钥：$e';
      notifyListeners();
      return;
    }

    final preflight = await runPreflightChecks();
    if (preflight.isNotEmpty) {
      _phase = PipelineRunPhase.failed;
      _error = preflight.join('\n');
      notifyListeners();
      return;
    }

    _phase = PipelineRunPhase.running;
    _startedAt = DateTime.now();
    _finishedAt = null;
    _exitCode = null;
    _error = null;
    _logLines.clear();
    _discoveredFailedCount = 0;
    _discoveredDoneCount = 0;
    _totalDiscoveredCount = 0;
    _lastRetryCommand = null;
    _lastRetryArgv = null;
    _imageJobs.clear();
    await reloadRunnableJobsFromDisk();
    _spaceSavedBytes = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _is429Backoff = false;
    _backoffSecondsRemaining = 0;
    _galleryPollTimer?.cancel();
    _galleryPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_phase == PipelineRunPhase.running) {
        unawaited(refreshOutputReviews());
      } else {
        _galleryPollTimer?.cancel();
        _galleryPollTimer = null;
      }
    });
    notifyListeners();

    try {
      final result = await _runner.run(
        config,
        onOutputLine: _processOutputLine,
      );
      _galleryPollTimer?.cancel();
      _galleryPollTimer = null;
      _exitCode = result.exitCode;
      _finishedAt = DateTime.now();
      _phase = result.wasCancelled
          ? PipelineRunPhase.idle
          : result.exitCode == 0
          ? PipelineRunPhase.success
          : PipelineRunPhase.failed;
      if (result.wasCancelled) {
        _error = '流水线已取消。';
        for (final job in _imageJobs.values) {
          if (job.geminiStage == GeminiStage.processing) {
            job.geminiStage = GeminiStage.pending;
          }
          if (job.cleanupStage == CleanupStage.processing) {
            job.cleanupStage = CleanupStage.pending;
          }
        }
        unawaited(_flushCancelledJobsToState());
      } else if (result.exitCode != 0) {
        _error = '流水线异常退出，代码：${result.exitCode}。';
      }
      await refreshOutputReviews();
    } on Exception catch (e) {
      _galleryPollTimer?.cancel();
      _galleryPollTimer = null;
      _phase = PipelineRunPhase.failed;
      _finishedAt = DateTime.now();
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> cancelPipeline() async {
    if (!isRunning) {
      return;
    }
    await _runner.cancelRun();
  }

  Future<void> retryFailed() async {
    final argv = _lastRetryArgv;
    if (argv == null || argv.isEmpty) {
      _error =
          '无法获取结构化重试命令。请在失败后再次运行流水线，以便后端输出 PRODUCT_IMAGE_PIPELINE_RETRY_JSON。';
      notifyListeners();
      return;
    }
    _phase = PipelineRunPhase.running;
    _startedAt = DateTime.now();
    _finishedAt = null;
    _exitCode = null;
    _error = null;
    _imageJobs.clear();
    _spaceSavedBytes = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _is429Backoff = false;
    _backoffSecondsRemaining = 0;
    _galleryPollTimer?.cancel();
    _galleryPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_phase == PipelineRunPhase.running) {
        unawaited(refreshOutputReviews());
      } else {
        _galleryPollTimer?.cancel();
        _galleryPollTimer = null;
      }
    });
    notifyListeners();
    try {
      final result = await _runner.runWithArgv(
        argv,
        onOutputLine: _processOutputLine,
      );
      _galleryPollTimer?.cancel();
      _galleryPollTimer = null;
      _exitCode = result.exitCode;
      _finishedAt = DateTime.now();
      _phase = result.wasCancelled
          ? PipelineRunPhase.idle
          : result.exitCode == 0
          ? PipelineRunPhase.success
          : PipelineRunPhase.failed;
      if (result.wasCancelled) {
        _error = '重试已取消。';
      } else if (result.exitCode != 0) {
        _error = '重试失败，退出代码：${result.exitCode}。';
      }
      await refreshOutputReviews();
    } on Exception catch (e) {
      _galleryPollTimer?.cancel();
      _galleryPollTimer = null;
      _phase = PipelineRunPhase.failed;
      _finishedAt = DateTime.now();
      _error = '重试失败：$e';
    }
    notifyListeners();
  }

  // ── Per-image log processing ───────────────────────────────────────────────

  void _processOutputLine(String line) {
    // JSON structured events go to _handleStructuredEvent; plain text goes to the log.
    if (line.startsWith('{')) {
      _handleStructuredEvent(line);
      notifyListeners();
      return;
    }
    _logLines.add(redactSecretsInLogLine(line));
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('uv run ')) _lastRetryCommand = trimmed;
    const retryPrefix = 'PRODUCT_IMAGE_PIPELINE_RETRY_JSON=';
    if (trimmed.startsWith(retryPrefix)) {
      try {
        final payload =
            jsonDecode(trimmed.substring(retryPrefix.length)) as Map<String, dynamic>;
        final argv = payload['argv'];
        if (argv is List) {
          _lastRetryArgv = argv.map((e) => '$e').toList();
        }
      } on FormatException {
        // Ignore malformed retry payload.
      }
    }
    notifyListeners();
  }

  void _startBackoffCountdown(int seconds, {String reason = 'rate_limit'}) {
    _is429Backoff = true;
    _backoffSecondsRemaining = seconds;
    _backoffReason = reason;
    _backoffTimer?.cancel();
    _backoffTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_backoffSecondsRemaining > 0) {
        _backoffSecondsRemaining -= 1;
        notifyListeners();
      } else {
        _is429Backoff = false;
        timer.cancel();
        _backoffTimer = null;
        notifyListeners();
      }
    });
  }

  /// Handles structured JSON event lines emitted by Python (JSON Lines on stdout).
  void _handleStructuredEvent(String line) {
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      final type = event['event'] as String?;
      switch (type) {
        case 'pipeline_scan':
          final total = (event['total'] as num?)?.toInt();
          if (total != null) {
            _totalDiscoveredCount = total;
          }
          final paths = event['paths'] as List<dynamic>?;
          if (paths != null) {
            final next = <String, ImageJobState>{};
            for (final p in paths) {
              final relPath = '$p';
              final nativePath = relPath.replaceAll('/', Platform.pathSeparator);
              final fullPath =
                  '${config.inputDir}${Platform.pathSeparator}$nativePath';
              final fileName = _fileNameFromPath(fullPath);
              final preserved = _imageJobs[fileName];
              next[fileName] = preserved ??
                  ImageJobState(fileName: fileName, inputPath: fullPath);
            }
            _imageJobs
              ..clear()
              ..addAll(next);
          }
          break;
        case 'image_start':
          final relPath = event['path'] as String?;
          if (relPath != null) {
            final nativePath = relPath.replaceAll('/', Platform.pathSeparator);
            final fullPath =
                '${config.inputDir}${Platform.pathSeparator}$nativePath';
            final fileName = _fileNameFromPath(fullPath);
            final job = _imageJobs[fileName] ??
                ImageJobState(fileName: fileName, inputPath: fullPath);
            job.geminiStage = GeminiStage.processing;
            job.cleanupStage = CleanupStage.pending;
            job.processingStartedAt = DateTime.now();
            _imageJobs[fileName] = job;
          }
          break;
        case 'gemini_done':
          final relPath = event['path'] as String?;
          if (relPath != null) {
            final nativePath = relPath.replaceAll('/', Platform.pathSeparator);
            final fullPath =
                '${config.inputDir}${Platform.pathSeparator}$nativePath';
            final fileName = _fileNameFromPath(fullPath);
            final job = _imageJobs[fileName] ??
                ImageJobState(fileName: fileName, inputPath: fullPath);
            job.geminiStage = GeminiStage.done;
            job.cleanupStage = CleanupStage.processing;
            final latencyMs = (event['latency_ms'] as num?)?.toInt();
            if (latencyMs != null) job.latencyMs = latencyMs;
            _imageJobs[fileName] = job;
          }
          break;
        case 'cleanup_done':
          final relPath = event['path'] as String?;
          if (relPath != null) {
            final nativePath = relPath.replaceAll('/', Platform.pathSeparator);
            final fullPath =
                '${config.inputDir}${Platform.pathSeparator}$nativePath';
            final fileName = _fileNameFromPath(fullPath);
            final job = _imageJobs[fileName];
            if (job != null) {
              job.cleanupStage = CleanupStage.done;
            }
          }
          break;
        case 'image_failed':
          final relPath = event['path'] as String?;
          if (relPath != null) {
            final nativePath = relPath.replaceAll('/', Platform.pathSeparator);
            final fullPath =
                '${config.inputDir}${Platform.pathSeparator}$nativePath';
            final fileName = _fileNameFromPath(fullPath);
            final job = _imageJobs[fileName] ??
                ImageJobState(fileName: fileName, inputPath: fullPath);
            final category = event['error_category'] as String?;
            if (category == 'safety_filter') {
              job.geminiStage = GeminiStage.safetyBlocked;
              job.errorType = ImageErrorType.safetyFilter;
            } else if (category == 'rate_limit') {
              job.geminiStage = GeminiStage.failed;
              job.errorType = ImageErrorType.quota;
            } else {
              job.geminiStage = GeminiStage.failed;
              job.errorType = ImageErrorType.apiError;
            }
            // Always clear cleanup spinner — failure terminates the image regardless
            // of which stage it was in when the error occurred.
            job.cleanupStage = CleanupStage.pending;
            job.errorMessage = event['error_msg'] as String?;
            _imageJobs[fileName] = job;
          }
          break;
        case 'backoff_start':
          final durationS = (event['duration_s'] as num?)?.toDouble() ?? 30.0;
          final reason = (event['reason'] as String?) ?? 'rate_limit';
          _startBackoffCountdown(durationS.ceil(), reason: reason);
          break;
        case 'backoff_end':
          _is429Backoff = false;
          _backoffTimer?.cancel();
          _backoffTimer = null;
          _backoffSecondsRemaining = 0;
          break;
        case 'progress':
          final done = (event['done'] as num?)?.toInt();
          final failed = (event['failed'] as num?)?.toInt();
          if (done != null) _discoveredDoneCount = done;
          if (failed != null) _discoveredFailedCount = failed;
          break;
        case 'pipeline_complete':
          final spaceSaved = (event['space_saved_bytes'] as num?)?.toInt();
          if (spaceSaved != null) _spaceSavedBytes = spaceSaved;
          break;
        default:
          break;
      }
    } on FormatException {
      // Not valid JSON — ignore.
    } on Object {
      // Any other error — ignore.
    }
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    final last = parts.last.trim();
    return last.isEmpty ? path : last;
  }

  Future<void> openOutputFolder() async {
    if (config.outputDir.isEmpty) return;
    await Process.run('open', [config.outputDir]);
  }

  File _pipelineStateFile() => File(p.join(config.inputDir, _kPipelineStateFilename));

  String _absolutePathForInputRel(Directory inputDir, String relPosix) {
    var base = inputDir.absolute.path;
    for (final part in relPosix.split('/')) {
      if (part.isEmpty || part == '.') {
        continue;
      }
      base = p.join(base, part);
    }
    return base;
  }

  Map<String, dynamic> _defaultImageRecordMap() => {
        'review': 'unreviewed',
        'gemini': 'pending',
        'cleanup': 'pending',
      };

  Map<String, dynamic> _normalizeImageRecordMap(Object? raw) {
    final rec = Map<String, dynamic>.from(_defaultImageRecordMap());
    if (raw is! Map) {
      return rec;
    }
    final r = raw['review'];
    if (r is String && _kReviewStrings.contains(r)) {
      rec['review'] = r;
    }
    final g = raw['gemini'];
    if (g is String && _kGeminiStrings.contains(g)) {
      rec['gemini'] = g;
    }
    final c = raw['cleanup'];
    if (c is String && _kCleanupStrings.contains(c)) {
      rec['cleanup'] = c;
    }
    return rec;
  }

  bool _imageRecordIsRunnableMap(Map<String, dynamic> rec) {
    final review = rec['review'] as String? ?? 'unreviewed';
    if (review == 'needsEdit' || review == 'rejected') {
      return true;
    }
    final gemini = rec['gemini'] as String? ?? 'pending';
    final cleanup = rec['cleanup'] as String? ?? 'pending';
    return gemini != 'done' || cleanup != 'done';
  }

  Map<String, Map<String, dynamic>> _migrateV1ToImagesMap(
    Map<String, dynamic> raw,
    Set<String> allKeys,
  ) {
    final proc = <String>{
      for (final e in (raw['processed'] as List<dynamic>? ?? const []))
        if (e != null) '$e',
    };
    proc.retainAll(allKeys);
    final out = <String, Map<String, dynamic>>{};
    for (final k in allKeys) {
      if (proc.contains(k)) {
        out[k] = {
          'review': 'unreviewed',
          'gemini': 'done',
          'cleanup': 'done',
        };
      } else {
        out[k] = _defaultImageRecordMap();
      }
    }
    return out;
  }

  Map<String, Map<String, dynamic>> _parseV2ImagesFromRaw(
    Map<String, dynamic> raw,
    Set<String> allKeys,
  ) {
    final rawImg = raw['images'];
    final out = <String, Map<String, dynamic>>{};
    if (rawImg is Map) {
      for (final e in rawImg.entries) {
        final k = '${e.key}';
        if (!allKeys.contains(k)) {
          continue;
        }
        out[k] = _normalizeImageRecordMap(e.value);
      }
    }
    for (final k in allKeys) {
      out.putIfAbsent(k, _defaultImageRecordMap);
    }
    return out;
  }

  /// Relative POSIX keys for all images under [inputDir].
  Future<Set<String>> _scanInputRelKeys(Directory inputDir) async {
    final root = inputDir.absolute;
    final keys = <String>{};
    if (!root.existsSync()) {
      return keys;
    }
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final dot = entity.path.toLowerCase().lastIndexOf('.');
      final ext = dot >= 0 ? entity.path.toLowerCase().substring(dot) : '';
      if (!_imageExtensions.contains(ext)) {
        continue;
      }
      final rel = p.relative(entity.path, from: root.path);
      keys.add(rel.replaceAll('\\', '/'));
    }
    return keys;
  }

  Future<void> _mergeLegacyReviewIntoImages(
    Map<String, Map<String, dynamic>> images,
    Set<String> allKeys,
  ) async {
    final legacy = File(p.join(config.outputDir, '.review_state.json'));
    if (!legacy.existsSync()) {
      return;
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final outRoot = Directory(config.outputDir).absolute;
    for (final e in data.entries) {
      final pathStr = e.key;
      final st = e.value;
      if (st is! String || !_kReviewStrings.contains(st)) {
        continue;
      }
      var pth = pathStr;
      if (!p.isAbsolute(pathStr)) {
        pth = p.join(outRoot.path, pathStr);
      }
      final f = File(pth);
      if (!f.existsSync()) {
        continue;
      }
      final relOut = p.relative(f.path, from: outRoot.path).replaceAll('\\', '/');
      final ik = _inputRelKeyForCleanOutputRel(relOut, allKeys, Directory(config.inputDir));
      if (ik != null) {
        final rec = Map<String, dynamic>.from(images[ik] ?? _defaultImageRecordMap());
        rec['review'] = st;
        images[ik] = rec;
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadMergedPipelineImagesMap(
    Directory inputDir,
    Set<String> allKeys,
  ) async {
    final path = File(p.join(inputDir.path, _kPipelineStateFilename));
    Map<String, dynamic> raw = {};
    if (path.existsSync()) {
      try {
        raw = jsonDecode(await path.readAsString()) as Map<String, dynamic>;
      } on Object {
        raw = {};
      }
    }
    final ver = raw['version'];
    final Map<String, Map<String, dynamic>> images;
    if (ver is num && ver >= 2 && raw['images'] is Map) {
      images = _parseV2ImagesFromRaw(raw, allKeys);
    } else {
      images = _migrateV1ToImagesMap(raw, allKeys);
    }
    await _mergeLegacyReviewIntoImages(images, allKeys);
    images.removeWhere((k, _) => !allKeys.contains(k));
    for (final k in allKeys) {
      images.putIfAbsent(k, _defaultImageRecordMap);
    }
    return images;
  }

  String? _inputRelKeyForCleanOutputRel(
    String relOutPosix,
    Set<String> allKeys,
    Directory inputDir,
  ) {
    if (!relOutPosix.endsWith('_product_clean.png')) {
      return null;
    }
    final stem = relOutPosix.substring(
      0,
      relOutPosix.length - '_product_clean.png'.length,
    );
    final slash = stem.lastIndexOf('/');
    final parentPosix = slash >= 0 ? stem.substring(0, slash) : '';
    final nameStem = slash >= 0 ? stem.substring(slash + 1) : stem;
    for (final k in allKeys) {
      final pk = p.Context(style: p.Style.posix);
      final parent = pk.dirname(k);
      final normParent = parent == '.' ? '' : parent;
      if (normParent != parentPosix) {
        continue;
      }
      final base = pk.basename(k);
      final dot = base.lastIndexOf('.');
      final inputStem = dot >= 0 ? base.substring(0, dot) : base;
      if (inputStem == nameStem) {
        return k;
      }
    }
    return null;
  }

  String? inputRelKeyForProductCleanFile(File cleanFile) {
    final inputPath = config.inputDir.trim();
    if (inputPath.isEmpty) {
      return null;
    }
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      return null;
    }
    final keys = <String>{};
    for (final e in inputDir.listSync(recursive: true, followLinks: false)) {
      if (e is! File) {
        continue;
      }
      final dot = e.path.toLowerCase().lastIndexOf('.');
      final ext = dot >= 0 ? e.path.toLowerCase().substring(dot) : '';
      if (!_imageExtensions.contains(ext)) {
        continue;
      }
      final rel = p.relative(e.path, from: inputDir.absolute.path);
      keys.add(rel.replaceAll('\\', '/'));
    }
    final outRoot = Directory(config.outputDir).absolute;
    final relOut = p.relative(cleanFile.path, from: outRoot.path).replaceAll('\\', '/');
    return _inputRelKeyForCleanOutputRel(relOut, keys, inputDir);
  }

  void _applyRecordToJob(ImageJobState job, Map<String, dynamic> rec) {
    job.geminiStage = _geminiStageFromString(rec['gemini'] as String?);
    job.cleanupStage = _cleanupStageFromString(rec['cleanup'] as String?);
  }

  GeminiStage _geminiStageFromString(String? s) {
    switch (s) {
      case 'processing':
        return GeminiStage.processing;
      case 'done':
        return GeminiStage.done;
      case 'failed':
        return GeminiStage.failed;
      case 'safetyBlocked':
        return GeminiStage.safetyBlocked;
      default:
        return GeminiStage.pending;
    }
  }

  CleanupStage _cleanupStageFromString(String? s) {
    switch (s) {
      case 'processing':
        return CleanupStage.processing;
      case 'done':
        return CleanupStage.done;
      default:
        return CleanupStage.pending;
    }
  }

  String _geminiStageToString(GeminiStage stage) {
    switch (stage) {
      case GeminiStage.processing:
        return 'processing';
      case GeminiStage.done:
        return 'done';
      case GeminiStage.failed:
        return 'failed';
      case GeminiStage.safetyBlocked:
        return 'safetyBlocked';
      case GeminiStage.pending:
        return 'pending';
    }
  }

  String _cleanupStageToString(CleanupStage stage) {
    switch (stage) {
      case CleanupStage.processing:
        return 'processing';
      case CleanupStage.done:
        return 'done';
      case CleanupStage.pending:
        return 'pending';
    }
  }

  Future<void> _flushCancelledJobsToState() async {
    final inputPath = config.inputDir.trim();
    if (inputPath.isEmpty) return;
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) return;

    final allKeys = await _scanInputRelKeys(inputDir);
    final images = await _loadMergedPipelineImagesMap(inputDir, allKeys);

    for (final job in _imageJobs.values) {
      final absInput = job.inputPath;
      if (absInput == null) continue;
      final relKey =
          p.relative(absInput, from: inputDir.absolute.path).replaceAll('\\', '/');
      final rec = Map<String, dynamic>.from(images[relKey] ?? _defaultImageRecordMap());
      rec['gemini'] = _geminiStageToString(job.geminiStage);
      rec['cleanup'] = _cleanupStageToString(job.cleanupStage);
      images[relKey] = rec;
    }

    await _writePipelineStateV2(images);
  }

  Future<void> reloadRunnableJobsFromDisk() async {
    if (isRunning) {
      return;
    }
    final inputPath = config.inputDir.trim();
    if (inputPath.isEmpty) {
      _imageJobs.clear();
      notifyListeners();
      return;
    }
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      _imageJobs.clear();
      notifyListeners();
      return;
    }
    final allKeys = await _scanInputRelKeys(inputDir);
    if (allKeys.isEmpty) {
      _imageJobs.clear();
      _totalDiscoveredCount = 0;
      notifyListeners();
      return;
    }
    final images = await _loadMergedPipelineImagesMap(inputDir, allKeys);
    _imageJobs.clear();
    for (final k in allKeys.toList()..sort()) {
      final rec = images[k] ?? _defaultImageRecordMap();
      if (!_imageRecordIsRunnableMap(rec)) {
        continue;
      }
      final absPath = _absolutePathForInputRel(inputDir, k);
      if (!File(absPath).existsSync()) {
        continue;
      }
      final fileName = p.basename(absPath);
      final job = ImageJobState(fileName: fileName, inputPath: absPath);
      _applyRecordToJob(job, rec);
      _imageJobs[fileName] = job;
    }
    _totalDiscoveredCount = _imageJobs.length;
    notifyListeners();
  }

  Future<void> _writePipelineStateV2(
    Map<String, Map<String, dynamic>> images,
  ) async {
    final f = _pipelineStateFile();
    f.parent.createSync(recursive: true);
    final payload = <String, dynamic>{
      'version': 2,
      'images': {
        for (final e in images.entries) e.key: e.value,
      },
    };
    await f.writeAsString('${jsonEncode(payload)}\n');
  }

  Future<void> _persistReviewForRelKey(String relKey, ReviewStatus status) async {
    final inputPath = config.inputDir.trim();
    if (inputPath.isEmpty) {
      return;
    }
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      return;
    }
    final allKeys = await _scanInputRelKeys(inputDir);
    final images = await _loadMergedPipelineImagesMap(inputDir, allKeys);
    final rec = Map<String, dynamic>.from(images[relKey] ?? _defaultImageRecordMap());
    rec['review'] = _statusToString(status);
    images[relKey] = rec;
    await _writePipelineStateV2(images);
    unawaited(reloadRunnableJobsFromDisk());
  }

  Future<void> refreshOutputReviews() async {
    final dir = Directory(config.outputDir);
    if (!dir.existsSync()) {
      _reviewItems.clear();
      notifyListeners();
      return;
    }
    // Snapshot in-memory non-unreviewed statuses so a disk read of "unreviewed"
    // (e.g. before an async persist completes) doesn't clobber them.
    final inMemoryStatuses = <String, ReviewStatus>{
      for (final item in _reviewItems)
        if (item.status != ReviewStatus.unreviewed) item.path: item.status,
    };
    final inputPath = config.inputDir.trim();
    final inputDir = inputPath.isNotEmpty && Directory(inputPath).existsSync()
        ? Directory(inputPath)
        : null;
    Set<String> allKeys = {};
    if (inputDir != null) {
      allKeys = await _scanInputRelKeys(inputDir);
    }
    final images = inputDir != null
        ? await _loadMergedPipelineImagesMap(inputDir, allKeys)
        : <String, Map<String, dynamic>>{};
    // Fallback: output-dir review file (keyed by output-relative path).
    // Used when inputDir isn't configured or key lookup fails.
    final fallbackReviews = await _loadOutputReviewFallback();
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_product_clean.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final outRoot = dir.absolute;
    _reviewItems
      ..clear()
      ..addAll(
        files.map((file) {
          ReviewStatus st = ReviewStatus.unreviewed;
          if (inputDir != null && allKeys.isNotEmpty) {
            final relOut =
                p.relative(file.path, from: outRoot.path).replaceAll('\\', '/');
            final ik = _inputRelKeyForCleanOutputRel(relOut, allKeys, inputDir);
            if (ik != null) {
              final rec = images[ik];
              if (rec != null) {
                st = _statusFromString(rec['review'] as String?);
              }
            }
          }
          // Check the output-dir fallback file if still unreviewed.
          if (st == ReviewStatus.unreviewed && fallbackReviews.isNotEmpty) {
            final relOut =
                p.relative(file.path, from: outRoot.path).replaceAll('\\', '/');
            final fb = fallbackReviews[relOut];
            if (fb != null) st = _statusFromString(fb);
          }
          // Prefer in-memory status over disk "unreviewed" to avoid resetting
          // statuses that were set but not yet flushed to disk.
          if (st == ReviewStatus.unreviewed) {
            final pending = inMemoryStatuses[file.path];
            if (pending != null) st = pending;
          }
          return OutputReviewItem(
            path: file.path,
            fileName: file.uri.pathSegments.isEmpty
                ? file.path
                : file.uri.pathSegments.last,
            status: st,
          );
        }),
      );
    notifyListeners();
  }

  Future<void> setReviewStatus(String path, ReviewStatus status) async {
    final idx = _reviewItems.indexWhere((item) => item.path == path);
    if (idx < 0) {
      return;
    }
    final item = _reviewItems[idx];
    _reviewItems[idx] = OutputReviewItem(
      path: item.path,
      fileName: item.fileName,
      status: status,
    );
    notifyListeners();
    final relKey = inputRelKeyForProductCleanFile(File(path));
    if (relKey != null) {
      await _persistReviewForRelKey(relKey, status);
    } else {
      // Fallback: persist keyed by output-relative path so reviews survive
      // restart even when inputDir is not configured or key lookup fails.
      await _persistOutputReviewFallback(path, status);
    }
  }

  // ── Fallback review persistence (output-dir keyed by output-rel path) ────────

  File _outputReviewFallbackFile() =>
      File(p.join(config.outputDir, '.output_review.json'));

  Future<Map<String, String>> _loadOutputReviewFallback() async {
    final f = _outputReviewFallbackFile();
    if (!f.existsSync()) return {};
    try {
      final data = jsonDecode(await f.readAsString());
      if (data is Map) {
        return {
          for (final e in data.entries)
            if (e.key is String && e.value is String) '${e.key}': '${e.value}',
        };
      }
    } on Object {
      // corrupt file — ignore
    }
    return {};
  }

  Future<void> _persistOutputReviewFallback(
    String absolutePath,
    ReviewStatus status,
  ) async {
    final outRoot = Directory(config.outputDir);
    if (!outRoot.existsSync()) return;
    final relOut =
        p.relative(absolutePath, from: outRoot.absolute.path).replaceAll('\\', '/');
    final existing = await _loadOutputReviewFallback();
    existing[relOut] = _statusToString(status);
    final f = _outputReviewFallbackFile();
    f.parent.createSync(recursive: true);
    await f.writeAsString('${jsonEncode(existing)}\n');
  }

  ReviewStatus _statusFromString(String? value) {
    switch (value) {
      case 'approved':
        return ReviewStatus.approved;
      case 'needsEdit':
        return ReviewStatus.needsEdit;
      case 'rejected':
        return ReviewStatus.rejected;
      default:
        return ReviewStatus.unreviewed;
    }
  }

  String _statusToString(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.approved:
        return 'approved';
      case ReviewStatus.needsEdit:
        return 'needsEdit';
      case ReviewStatus.rejected:
        return 'rejected';
      case ReviewStatus.unreviewed:
        return 'unreviewed';
    }
  }

  File _settingsFile() => File('$applicationSupportPath/settings.json');

  Future<void> _loadSavedState() async {
    final file = _settingsFile();
    if (!file.existsSync()) {
      return;
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      config.inputDir = (raw['inputDir'] as String?) ?? config.inputDir;
      config.outputDir = (raw['outputDir'] as String?) ?? config.outputDir;
      final workersRaw = raw['workers'];
      if (workersRaw is int) {
        config.workers = workersRaw;
      } else if (workersRaw is num) {
        config.workers = workersRaw.toInt();
      }
      final retriesRaw = raw['maxApiRetries'];
      if (retriesRaw is int) {
        config.maxApiRetries = retriesRaw;
      } else if (retriesRaw is num) {
        config.maxApiRetries = retriesRaw.toInt();
      }
      final kr = raw['keepRaw'];
      if (kr is bool) {
        config.keepRaw = kr;
      }
      final ar = raw['aspectRatio'];
      if (ar is String && ar.isNotEmpty) {
        config.aspectRatio = ar;
      }
      final od = raw['outputDimension'];
      if (od is int) {
        config.outputDimension = od;
      } else if (od is num) {
        config.outputDimension = od.toInt();
      }
      final ol = raw['outputLandscape'];
      if (ol is bool) {
        config.outputLandscape = ol;
      }
      notifyListeners();
    } on FormatException {
      // Ignore invalid saved state.
    }
  }

  Future<void> _saveSettings() async {
    // Never add API keys here — settings.json must stay safe to inspect and is not for secrets.
    final file = _settingsFile();
    final payload = <String, dynamic>{
      'inputDir': config.inputDir,
      'outputDir': config.outputDir,
      'workers': config.workers,
      'maxApiRetries': config.maxApiRetries,
      'keepRaw': config.keepRaw,
      if (config.aspectRatio != null) 'aspectRatio': config.aspectRatio,
      if (config.outputDimension != null) 'outputDimension': config.outputDimension,
      'outputLandscape': config.outputLandscape,
    };
    await file.writeAsString(jsonEncode(payload));
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({required AppState appState, required super.child, super.key})
    : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppStateScope is missing in widget tree.');
    }
    return scope.notifier!;
  }
}
