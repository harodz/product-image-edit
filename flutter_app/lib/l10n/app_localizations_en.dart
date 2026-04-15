// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Product Image Editor';

  @override
  String get navBrand => 'Product\nPipeline';

  @override
  String get navPipelineSettings => 'Pipeline Settings';

  @override
  String get navBatchDashboard => 'Batch Dashboard';

  @override
  String get navOutputGallery => 'Output Gallery';

  @override
  String get navApiAccount => 'API & account';

  @override
  String get dropFolderHint => 'Drop folder or image, or browse';

  @override
  String get selectImages => 'Select Image(s)';

  @override
  String get browseFolder => 'Browse Folder';

  @override
  String get dialogSelectFolder => 'Select folder';

  @override
  String get dialogSelectImages => 'Select image(s)';

  @override
  String get screenPipelineSettings => 'Pipeline Settings';

  @override
  String get sectionBatchConfiguration => 'BATCH CONFIGURATION';

  @override
  String get inputFolderOrImage => 'Input folder or image';

  @override
  String get outputDirectory => 'Output Directory';

  @override
  String get sectionExecutionParameters => 'EXECUTION PARAMETERS';

  @override
  String get flagWorkers => '--workers';

  @override
  String get workersMinLabel => '1 JOB';

  @override
  String get workersMaxLabel => '64 JOBS (MAX)';

  @override
  String get flagMaxApiRetries => '--max-api-retries';

  @override
  String get maxApiRetriesHelp =>
      'Maximum attempts per file before flagging failure.';

  @override
  String get flagKeepRaw => '--keep-raw';

  @override
  String get keepRawSubtitle => 'Preserve original buffers alongside output.';

  @override
  String get flagFailFast => '--fail-fast';

  @override
  String get failFastSubtitle => 'Abort pipeline on first error.';

  @override
  String get moreOptions => 'More options';

  @override
  String get promptLabel => 'Prompt';

  @override
  String get useResponseModalities => 'Use response modalities';

  @override
  String get copyFailed => 'Copy failed';

  @override
  String get noProgress => 'No progress';

  @override
  String get pipelineRunning => 'Pipeline running';

  @override
  String get allSystemsOperational => 'All systems operational';

  @override
  String get cancel => 'Cancel';

  @override
  String get previewCommand => 'Preview Command';

  @override
  String get runningEllipsis => 'Running...';

  @override
  String get runPipeline => 'Run Pipeline';

  @override
  String get commandPreview => 'Command Preview';

  @override
  String get close => 'Close';

  @override
  String get sectionNeuralModel => 'NEURAL MODEL';

  @override
  String get modelDescRecommended => 'Recommended · High Accuracy';

  @override
  String get modelDescFast => 'Fast Inference';

  @override
  String get modelDescLegacy => 'Legacy · Stable';

  @override
  String get customModel => 'Custom model';

  @override
  String get activeBadge => 'ACTIVE';

  @override
  String get currentProfile => 'CURRENT PROFILE';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusDone => 'Done';

  @override
  String get statusFailed => 'Failed';

  @override
  String get profileWorkers => 'Workers';

  @override
  String get profileRetries => 'Retries';

  @override
  String get profileOutputImages => 'Output images';

  @override
  String get tipsHeading => 'TIPS';

  @override
  String get tipsBody =>
      '• Lower workers if you see repeated 429 errors.\n• Re-run to resume from checkpoint.\n• Set API key in API & account.';

  @override
  String get screenApiAccount => 'API & account';

  @override
  String get geminiApiKeyTitle => 'Gemini API key';

  @override
  String get geminiApiKeyDescription =>
      'Saved automatically to your app data folder as you type (and when you leave this field). It is not embedded in the app bundle.';

  @override
  String get apiKeyHint => 'GEMINI_API_KEY';

  @override
  String get showKey => 'Show key';

  @override
  String get hideKey => 'Hide key';

  @override
  String lastSavedAt(String time) {
    return 'Last saved: $time';
  }

  @override
  String get apiKeySaved => 'API key saved';

  @override
  String get saveNow => 'Save now';

  @override
  String get storagePath => 'Storage path';

  @override
  String get screenOutputGallery => 'Output Review Gallery';

  @override
  String outputItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get processedLabel => 'processed';

  @override
  String get filterAll => 'All';

  @override
  String get filterApproved => 'Approved';

  @override
  String get filterNeedsEdit => 'Needs Edit';

  @override
  String get filterRejected => 'Rejected';

  @override
  String get filterUnreviewed => 'Unreviewed';

  @override
  String get tooltipSelectAll => 'Select all';

  @override
  String get tooltipDeselectAll => 'Deselect all';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get noImagesInView => 'No images in this view.';

  @override
  String itemsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items selected',
      one: '1 item selected',
    );
    return '$_temp0';
  }

  @override
  String get rejectSelected => 'Reject Selected';

  @override
  String get approveSelected => 'Approve Selected';

  @override
  String get screenBatchDashboard => 'Batch Dashboard';

  @override
  String get metricEta => 'ETA';

  @override
  String get emDash => '—';

  @override
  String get metricThroughput => 'Throughput';

  @override
  String get perMinute => '/min';

  @override
  String get metricSuccessRate => 'Success Rate';

  @override
  String imagesProgressNone(int done) {
    return '$done images';
  }

  @override
  String imagesProgressTotal(int done, int total) {
    return '$done / $total images';
  }

  @override
  String geminiActiveLabel(int count) {
    return '$count Gemini';
  }

  @override
  String cleanupActiveLabel(int count) {
    return '$count Cleanup';
  }

  @override
  String backoffSeconds(int seconds) {
    return 'Backoff: ${seconds}s';
  }

  @override
  String workersActiveLabel(int active, int total) {
    return '$active/$total Workers Active';
  }

  @override
  String get rateLimitWaiting => 'Rate limit — waiting';

  @override
  String get serverErrorWaiting => 'Server error — waiting';

  @override
  String get cancelPipeline => 'Cancel';

  @override
  String get cancellingLabel => 'Cancelling…';

  @override
  String get gridFilename => 'FILENAME';

  @override
  String get gridGemini => 'GEMINI';

  @override
  String get gridCleanup => 'CLEANUP';

  @override
  String get gridLatency => 'LATENCY';

  @override
  String get gridActions => 'ACTIONS';

  @override
  String get logs => 'Logs';

  @override
  String get retry => 'Retry';

  @override
  String logsForFile(String fileName) {
    return 'Logs — $fileName';
  }

  @override
  String get noLogEntriesForFile => 'No log entries for this file.';

  @override
  String get emptyWaitingFirstImage => 'Waiting for first image...';

  @override
  String get emptyNoActiveRun => 'No active run';

  @override
  String get emptyWaitingFirstImageSub =>
      'Images will appear here as they are processed.';

  @override
  String get emptyNoActiveRunSub =>
      'Run a pipeline from Pipeline Settings to begin. If the input folder has files but this list is empty, they are skipped until you mark them needs edit or rejected in the Output Gallery (see _pipeline_image_state.json).';

  @override
  String get failuresHeading => 'Failures';

  @override
  String get errorGroupSafetyFilter => 'Safety Filter';

  @override
  String get errorGroupRateLimit => 'Rate Limit';

  @override
  String get errorGroupApiError => 'API Error';

  @override
  String get retryAllFailed => 'Retry All Failed';

  @override
  String get openOutputFolder => 'Open Output Folder';

  @override
  String get workersLabel => 'Workers';

  @override
  String get takesEffectNextRetry => 'Takes effect on next retry';

  @override
  String get consoleHeading => 'Console';

  @override
  String consoleErrorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get noOutputYet => 'No output yet.';

  @override
  String get batchComplete => 'Batch Complete';

  @override
  String batchCompleteSubtitle(int done, int total, String durationPart) {
    return '$done / $total images processed$durationPart';
  }

  @override
  String durationPartIn(String duration) {
    return ' in $duration';
  }

  @override
  String spaceSaved(String size) {
    return 'Space saved: $size';
  }

  @override
  String get startNewBatch => 'Start New Batch';

  @override
  String durationHm(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMs(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String durationS(int seconds) {
    return '${seconds}s';
  }

  @override
  String durationHms(int hours, int minutes, int seconds) {
    return '${hours}h ${minutes}m ${seconds}s';
  }
}
