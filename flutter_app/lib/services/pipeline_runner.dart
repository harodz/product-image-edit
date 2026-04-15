import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app/app_state.dart';

class PipelineRunResult {
  const PipelineRunResult({required this.exitCode, required this.wasCancelled});

  final int exitCode;
  final bool wasCancelled;
}

class PipelineRunner {
  Process? _activeProcess;
  String? _applicationSupportDirectory;

  /// Same path passed to the Python process via [PRODUCT_IMAGE_EDIT_APP_DATA].
  void setApplicationSupportDirectory(String path) {
    _applicationSupportDirectory = path;
  }

  String buildCommandPreview(PipelineConfig config) {
    final cmd = _buildCommand(config);
    return [cmd.executable, ...cmd.arguments].map(_quoteIfNeeded).join(' ');
  }

  Future<List<String>> runPreflightChecks(PipelineConfig config) async {
    final checks = <String>[];
    final bundled = _resolveBundledRunner();
    if (bundled == null) {
      final uv = await _detectUvExec();
      if (uv == null) {
        final python = await _detectPythonExec();
        if (python == null) {
          checks.add(
            '未找到 uv 或 Python。请安装 uv（https://docs.astral.sh/uv/）以自动管理依赖，'
            '或安装 Python 3 并安装 google-genai、pillow、python-dotenv、tqdm。',
          );
        } else {
          checks.add(
            '未找到 uv，将使用系统 python3。依赖（google-genai、pillow 等）需手动安装。'
            '建议安装 uv 以自动管理依赖。',
          );
        }
      }
      final script = _resolvePipelineScript();
      if (!script.existsSync()) {
        checks.add('未找到流水线脚本：${script.path}');
      }
    }

    final support = _applicationSupportDirectory;
    final candidates = <File>[];
    if (bundled == null) {
      candidates.add(File('${_resolveProjectRoot().path}/.env'));
    }
    if (support != null && support.isNotEmpty) {
      candidates.add(File('$support/.env'));
    }
    String? envPathWithKey;
    for (final f in candidates) {
      if (!f.existsSync()) {
        continue;
      }
      String contents;
      try {
        contents = f.readAsStringSync();
      } on PathAccessException {
        // macOS sandbox may block reads outside the app container; skip candidate.
        continue;
      } on FileSystemException {
        continue;
      }
      final key = readApiKeyFromEnvText(contents);
      if (key != null && key.isNotEmpty) {
        envPathWithKey = f.path;
        break;
      }
    }
    if (envPathWithKey == null) {
      final hint = candidates.isNotEmpty
          ? '请在 ${candidates.first.path} 中添加密钥，或使用应用内的 API 密钥输入框。'
          : '请设置 GEMINI_API_KEY（参见仓库中的 .env.example）。';
      checks.add('未找到 GEMINI_API_KEY 或 GOOGLE_API_KEY。$hint');
    }
    return checks;
  }

  Future<PipelineRunResult> run(
    PipelineConfig config, {
    required void Function(String line) onOutputLine,
  }) async {
    final cmd = await _buildCommandAsync(config);
    return _runProcess(cmd, onOutputLine);
  }

  /// Same as [run] but with a raw argv (e.g. from PRODUCT_IMAGE_PIPELINE_RETRY_JSON).
  Future<PipelineRunResult> runWithArgv(
    List<String> arguments, {
    required void Function(String line) onOutputLine,
  }) async {
    final cmd = await _buildRawCommandAsync(arguments);
    return _runProcess(cmd, onOutputLine);
  }

  Future<PipelineRunResult> _runProcess(
    _PipelineCommand cmd,
    void Function(String line) onOutputLine,
  ) async {
    if (kDebugMode) {
      final bundled = _resolveBundledRunner();
      if (bundled != null) {
        debugPrint('PipelineRunner: using bundled ${bundled.path}');
      } else {
        debugPrint(
          'PipelineRunner: using ${cmd.executable} (no bundled pipeline_runner in .app)',
        );
      }
    }
    final process = await Process.start(
      cmd.executable,
      cmd.arguments,
      workingDirectory: cmd.workingDirectory,
      environment: cmd.environment,
    );
    _activeProcess = process;

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onOutputLine);
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onOutputLine);

    final results = await Future.wait<Object?>([
      process.exitCode,
      stdoutSub.asFuture<void>(),
      stderrSub.asFuture<void>(),
    ]);
    final exitCode = results[0] as int;
    final wasCancelled = exitCode == -15 || exitCode == 130;
    _activeProcess = null;
    return PipelineRunResult(exitCode: exitCode, wasCancelled: wasCancelled);
  }

  Future<void> cancelRun() async {
    final process = _activeProcess;
    if (process == null) {
      return;
    }
    process.kill(ProcessSignal.sigterm);
  }

  Future<_PipelineCommand> _buildCommandAsync(PipelineConfig config) async {
    final bundled = _resolveBundledRunner();
    final wd = _workingDirectoryForProcess();
    final env = _processEnvironment();
    if (bundled != null) {
      return _PipelineCommand(
        executable: bundled.path,
        arguments: _pipelineArgs(config),
        workingDirectory: wd,
        environment: env,
      );
    }
    return _buildScriptCommand(
      extraArgs: _pipelineArgs(config),
      workingDirectory: wd,
      environment: env,
    );
  }

  Future<_PipelineCommand> _buildRawCommandAsync(List<String> arguments) async {
    final bundled = _resolveBundledRunner();
    final wd = _workingDirectoryForProcess();
    final env = _processEnvironment();
    if (bundled != null) {
      return _PipelineCommand(
        executable: bundled.path,
        arguments: arguments,
        workingDirectory: wd,
        environment: env,
      );
    }
    return _buildScriptCommand(
      extraArgs: arguments,
      workingDirectory: wd,
      environment: env,
    );
  }

  /// Builds a command that runs the pipeline script via `uv run` (preferred,
  /// handles the venv and dependencies automatically) or bare python3 as fallback.
  Future<_PipelineCommand> _buildScriptCommand({
    required List<String> extraArgs,
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final scriptPath = _resolvePipelineScript().path;
    final uvExec = await _detectUvExec();
    if (uvExec != null) {
      return _PipelineCommand(
        executable: uvExec,
        arguments: ['run', 'python', scriptPath, ...extraArgs],
        workingDirectory: workingDirectory,
        environment: environment,
      );
    }
    final pythonExec = await _detectPythonExec();
    if (pythonExec == null) {
      throw Exception('未找到 uv 或 Python 可执行文件。');
    }
    return _PipelineCommand(
      executable: pythonExec,
      arguments: [scriptPath, ...extraArgs],
      workingDirectory: workingDirectory,
      environment: environment,
    );
  }

  _PipelineCommand _buildCommand(PipelineConfig config) {
    final bundled = _resolveBundledRunner();
    final wd = _workingDirectoryForProcess();
    final env = _processEnvironment();
    if (bundled != null) {
      return _PipelineCommand(
        executable: bundled.path,
        arguments: _pipelineArgs(config),
        workingDirectory: wd,
        environment: env,
      );
    }
    // Sync preview — assume uv; actual run detects at launch time.
    return _PipelineCommand(
      executable: 'uv',
      arguments: ['run', 'python', _resolvePipelineScript().path, ..._pipelineArgs(config)],
      workingDirectory: wd,
      environment: env,
    );
  }

  Map<String, String> _processEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final support = _applicationSupportDirectory;
    if (support != null && support.isNotEmpty) {
      env['PRODUCT_IMAGE_EDIT_APP_DATA'] = support;
    }
    return env;
  }

  String _workingDirectoryForProcess() {
    if (_resolveBundledRunner() != null) {
      final dir = _applicationSupportDirectory ?? Directory.current.path;
      Directory(dir).createSync(recursive: true);
      return dir;
    }
    return _resolveProjectRoot().path;
  }

  List<String> _pipelineArgs(PipelineConfig config) {
    return [
      config.inputDir,
      '--output-dir',
      config.outputDir,
      '--prompt',
      config.prompt,
      '--model',
      config.model,
      '--workers',
      config.workers.toString(),
      '--max-api-retries',
      config.maxApiRetries.toString(),
      if (config.keepRaw) '--keep-raw',
      if (config.failFast) '--fail-fast',
      if (config.useResponseModalities) '--use-response-modalities',
      if (config.copyFailed) '--copy-failed',
      if (config.noProgress) '--no-progress',
    ];
  }

  Future<String?> _detectUvExec() async {
    final candidates = [
      'uv',
      // GUI apps get a stripped PATH — probe the common install locations.
      if (Platform.isMacOS || Platform.isLinux) ...[
        '${Platform.environment['HOME']}/.cargo/bin/uv',
        '${Platform.environment['HOME']}/.local/bin/uv',
        '/opt/homebrew/bin/uv',
        '/usr/local/bin/uv',
      ],
      if (Platform.isWindows) ...[
        '${Platform.environment['USERPROFILE']}\\.local\\bin\\uv.exe',
        '${Platform.environment['USERPROFILE']}\\.cargo\\bin\\uv.exe',
        '${Platform.environment['LOCALAPPDATA']}\\Programs\\uv\\uv.exe',
      ],
    ];
    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, const ['--version']);
        if (result.exitCode == 0) return candidate;
      } on Exception {
        continue;
      }
    }
    return null;
  }

  Future<String?> _detectPythonExec() async {
    // 'py' is the Python Launcher for Windows, preferred when python3 is absent.
    final pathCandidates = Platform.isWindows
        ? const ['python', 'py', 'python3']
        : const ['python3', 'python'];
    for (final candidate in pathCandidates) {
      try {
        final result = await Process.run(candidate, const ['--version']);
        if (result.exitCode == 0) {
          return candidate;
        }
      } on Exception {
        continue;
      }
    }
    // GUI apps from Flutter/Xcode often get a tiny PATH (no Homebrew). Probe known locations.
    final absoluteCandidates = <String>[
      if (Platform.isMacOS) ...[
        '/usr/bin/python3',
        '/opt/homebrew/bin/python3',
        '/usr/local/bin/python3',
      ],
      if (Platform.isLinux) '/usr/bin/python3',
    ];
    for (final path in absoluteCandidates) {
      if (!File(path).existsSync()) {
        continue;
      }
      try {
        final result = await Process.run(path, const ['--version']);
        if (result.exitCode == 0) {
          return path;
        }
      } on Exception {
        continue;
      }
    }
    return null;
  }

  Directory _resolveProjectRoot() {
    Directory? walkUp(Directory start, int maxSteps) {
      var dir = start;
      for (var i = 0; i < maxSteps; i++) {
        if (File('${dir.path}/gemini_product_pipeline.py').existsSync()) {
          return dir;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
      return null;
    }

    // Walk up from the executable (works for both `flutter run` and release .app).
    final fromExe = walkUp(File(Platform.resolvedExecutable).parent, 20);
    if (fromExe != null) return fromExe;

    return walkUp(Directory.current, 12) ??
        walkUp(Directory.fromUri(Platform.script), 20) ??
        Directory.current;
  }

  File _resolvePipelineScript() {
    return File('${_resolveProjectRoot().path}/gemini_product_pipeline.py');
  }

  File? _resolveBundledRunner() {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent;
    final candidates = <String>[
      if (Platform.isMacOS) '${exeDir.parent.path}/Resources/backend/pipeline_runner',
      if (Platform.isLinux) '${exeDir.path}/data/flutter_assets/backend/pipeline_runner',
      if (Platform.isWindows)
        '${exeDir.path}\\data\\flutter_assets\\backend\\pipeline_runner.exe',
    ];
    for (final candidate in candidates) {
      final binary = File(candidate);
      if (binary.existsSync()) {
        return binary;
      }
    }
    return null;
  }

  String _quoteIfNeeded(String value) {
    if (!value.contains(' ')) {
      return value;
    }
    if (Platform.isWindows) {
      return '"${value.replaceAll('"', '\\"')}"';
    }
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  /// Parse `GEMINI_API_KEY` / `GOOGLE_API_KEY` from `.env` text (first match wins).
  static String? readApiKeyFromEnvText(String content) {
    for (final raw in content.split('\n')) {
      final t = raw.trim();
      if (t.isEmpty || t.startsWith('#')) {
        continue;
      }
      final m = RegExp(
        r'^(?:export\s+)?(GEMINI_API_KEY|GOOGLE_API_KEY)\s*=\s*(.*)$',
      ).firstMatch(t);
      if (m == null) {
        continue;
      }
      var v = m.group(2)!.trim();
      if (v.length >= 2) {
        if (v.startsWith('"') && v.endsWith('"')) {
          v = v.substring(1, v.length - 1);
        } else if (v.startsWith("'") && v.endsWith("'")) {
          v = v.substring(1, v.length - 1);
        }
      }
      if (v.isNotEmpty) {
        return v;
      }
    }
    return null;
  }

  /// Dev: project `.env` first (matches `uv run` workflow), then app support.
  /// Shipped: app support only.
  Future<String?> loadExistingApiKeyForDisplay() async {
    final bundled = _resolveBundledRunner() != null;
    final support = _applicationSupportDirectory;
    final files = <File>[];
    if (!bundled) {
      files.add(File('${_resolveProjectRoot().path}/.env'));
    }
    if (support != null && support.isNotEmpty) {
      files.add(File('$support/.env'));
    }
    for (final f in files) {
      if (!f.existsSync()) {
        continue;
      }
      try {
        final text = await f.readAsString();
        final key = readApiKeyFromEnvText(text);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  /// Writes [apiKey] as `GEMINI_API_KEY` in app support `.env` (removes prior API key lines).
  /// Empty [apiKey] removes both `GEMINI_API_KEY` and `GOOGLE_API_KEY` from that file.
  Future<void> writeGeminiApiKey(String apiKey) async {
    final support = _applicationSupportDirectory;
    if (support == null || support.isEmpty) {
      throw StateError('Application support directory is not set.');
    }
    await Directory(support).create(recursive: true);
    final file = File('$support/.env');
    final keptLines = <String>[];
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          keptLines.add(line);
          continue;
        }
        if (RegExp(r'^\s*(GEMINI_API_KEY|GOOGLE_API_KEY)\s*=').hasMatch(line)) {
          continue;
        }
        keptLines.add(line);
      }
    }
    if (apiKey.isNotEmpty) {
      keptLines.add('GEMINI_API_KEY=${_escapeEnvScalar(apiKey)}');
    }
    final body = keptLines.isEmpty ? '' : '${keptLines.join('\n')}\n';
    await file.writeAsString(body);
  }

  static String _escapeEnvScalar(String v) {
    final needsQuotes = v.contains(' ') ||
        v.contains('#') ||
        v.contains('"') ||
        v.contains("'") ||
        v.contains('\n') ||
        v.contains('\\');
    if (!needsQuotes) {
      return v;
    }
    final escaped = v.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }
}

class _PipelineCommand {
  const _PipelineCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;
}
