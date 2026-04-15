// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '产品图像编辑器';

  @override
  String get navBrand => '产品\n流水线';

  @override
  String get navPipelineSettings => '流水线设置';

  @override
  String get navBatchDashboard => '批处理仪表盘';

  @override
  String get navOutputGallery => '输出图库';

  @override
  String get navApiAccount => 'API 与账户';

  @override
  String get dropFolderHint => '拖入文件夹或图片，或点击浏览';

  @override
  String get selectImages => '选择图片';

  @override
  String get browseFolder => '浏览文件夹';

  @override
  String get dialogSelectFolder => '选择文件夹';

  @override
  String get dialogSelectImages => '选择图片';

  @override
  String get screenPipelineSettings => '流水线设置';

  @override
  String get sectionBatchConfiguration => '批处理配置';

  @override
  String get inputFolderOrImage => '输入文件夹或图片';

  @override
  String get outputDirectory => '输出目录';

  @override
  String get sectionExecutionParameters => '执行参数';

  @override
  String get flagWorkers => '--workers';

  @override
  String get workersMinLabel => '1 并发';

  @override
  String get workersMaxLabel => '64 并发（最大）';

  @override
  String get flagMaxApiRetries => '--max-api-retries';

  @override
  String get maxApiRetriesHelp => '每个文件在标记为失败前的最大尝试次数。';

  @override
  String get flagKeepRaw => '--keep-raw';

  @override
  String get keepRawSubtitle => '在输出旁保留原始缓冲数据。';

  @override
  String get flagFailFast => '--fail-fast';

  @override
  String get failFastSubtitle => '首次出错时中止流水线。';

  @override
  String get moreOptions => '更多选项';

  @override
  String get promptLabel => '提示词';

  @override
  String get useResponseModalities => '使用响应模态';

  @override
  String get copyFailed => '复制失败项';

  @override
  String get noProgress => '不显示进度';

  @override
  String get pipelineRunning => '流水线运行中';

  @override
  String get allSystemsOperational => '系统就绪';

  @override
  String get cancel => '取消';

  @override
  String get previewCommand => '预览命令';

  @override
  String get runningEllipsis => '运行中…';

  @override
  String get runPipeline => '运行流水线';

  @override
  String get commandPreview => '命令预览';

  @override
  String get close => '关闭';

  @override
  String get sectionNeuralModel => '模型';

  @override
  String get modelDescRecommended => '推荐 · 高精度';

  @override
  String get modelDescFast => '快速推理';

  @override
  String get modelDescLegacy => '旧版 · 稳定';

  @override
  String get customModel => '自定义模型';

  @override
  String get activeBadge => '已选';

  @override
  String get currentProfile => '当前配置';

  @override
  String get statusReady => '就绪';

  @override
  String get statusRunning => '运行中';

  @override
  String get statusDone => '完成';

  @override
  String get statusFailed => '失败';

  @override
  String get profileWorkers => '并发数';

  @override
  String get profileRetries => '重试次数';

  @override
  String get profileOutputImages => '输出图片';

  @override
  String get tipsHeading => '提示';

  @override
  String get tipsBody =>
      '• 若频繁出现 429，请降低并发数。\n• 重新运行可从检查点继续。\n• 请在「API 与账户」中设置 API 密钥。';

  @override
  String get screenApiAccount => 'API 与账户';

  @override
  String get geminiApiKeyTitle => 'Gemini API 密钥';

  @override
  String get geminiApiKeyDescription =>
      '输入内容会自动保存到应用数据目录（离开输入框时也会保存）。密钥不会打包进应用本体。';

  @override
  String get apiKeyHint => 'GEMINI_API_KEY';

  @override
  String get showKey => '显示密钥';

  @override
  String get hideKey => '隐藏密钥';

  @override
  String lastSavedAt(String time) {
    return '上次保存：$time';
  }

  @override
  String get apiKeySaved => 'API 密钥已保存';

  @override
  String get saveNow => '立即保存';

  @override
  String get storagePath => '存储路径';

  @override
  String get screenOutputGallery => '输出审阅图库';

  @override
  String outputItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '$_temp0';
  }

  @override
  String get processedLabel => '已处理';

  @override
  String get filterAll => '全部';

  @override
  String get filterApproved => '已通过';

  @override
  String get filterNeedsEdit => '需修改';

  @override
  String get filterRejected => '已拒绝';

  @override
  String get filterUnreviewed => '未审阅';

  @override
  String get tooltipSelectAll => '全选';

  @override
  String get tooltipDeselectAll => '取消全选';

  @override
  String get tooltipRefresh => '刷新';

  @override
  String get noImagesInView => '当前视图下没有图片。';

  @override
  String itemsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 项',
    );
    return '$_temp0';
  }

  @override
  String get rejectSelected => '拒绝所选';

  @override
  String get approveSelected => '通过所选';

  @override
  String get screenBatchDashboard => '批处理仪表盘';

  @override
  String get metricEta => '预计剩余';

  @override
  String get emDash => '—';

  @override
  String get metricThroughput => '吞吐量';

  @override
  String get perMinute => '/分钟';

  @override
  String get metricSuccessRate => '成功率';

  @override
  String imagesProgressNone(int done) {
    return '$done 张图片';
  }

  @override
  String imagesProgressTotal(int done, int total) {
    return '$done / $total 张图片';
  }

  @override
  String geminiActiveLabel(int count) {
    return '$count 路 Gemini';
  }

  @override
  String cleanupActiveLabel(int count) {
    return '$count 路清理';
  }

  @override
  String backoffSeconds(int seconds) {
    return '退避：$seconds 秒';
  }

  @override
  String workersActiveLabel(int active, int total) {
    return '$active/$total 个 Worker 活动中';
  }

  @override
  String get rateLimitWaiting => '限速 — 等待中';

  @override
  String get serverErrorWaiting => '服务器错误 — 等待中';

  @override
  String get cancelPipeline => '取消';

  @override
  String get cancellingLabel => '取消中…';

  @override
  String get gridFilename => '文件名';

  @override
  String get gridGemini => 'GEMINI';

  @override
  String get gridCleanup => '清理';

  @override
  String get gridLatency => '耗时';

  @override
  String get gridActions => '操作';

  @override
  String get logs => '日志';

  @override
  String get retry => '重试';

  @override
  String logsForFile(String fileName) {
    return '日志 — $fileName';
  }

  @override
  String get noLogEntriesForFile => '此文件暂无日志条目。';

  @override
  String get emptyWaitingFirstImage => '等待首张图片…';

  @override
  String get emptyNoActiveRun => '暂无运行任务';

  @override
  String get emptyWaitingFirstImageSub => '图片处理后将显示在此处。';

  @override
  String get emptyNoActiveRunSub =>
      '请在「流水线设置」中启动流水线。若输入文件夹中有文件但列表为空，表示这些文件已被跳过，请在输出图库中将对应项标为「需修改」或「已拒绝」后重试（参见 _pipeline_image_state.json）。';

  @override
  String get failuresHeading => '失败';

  @override
  String get errorGroupSafetyFilter => '安全过滤';

  @override
  String get errorGroupRateLimit => '限速';

  @override
  String get errorGroupApiError => 'API 错误';

  @override
  String get retryAllFailed => '重试全部失败项';

  @override
  String get openOutputFolder => '打开输出文件夹';

  @override
  String get workersLabel => '并发数';

  @override
  String get takesEffectNextRetry => '在下次重试时生效';

  @override
  String get consoleHeading => '控制台';

  @override
  String consoleErrorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个错误',
    );
    return '$_temp0';
  }

  @override
  String get noOutputYet => '暂无输出。';

  @override
  String get batchComplete => '批处理完成';

  @override
  String batchCompleteSubtitle(int done, int total, String durationPart) {
    return '已处理 $done / $total 张图片$durationPart';
  }

  @override
  String durationPartIn(String duration) {
    return '，耗时 $duration';
  }

  @override
  String spaceSaved(String size) {
    return '节省空间：$size';
  }

  @override
  String get startNewBatch => '开始新批次';

  @override
  String durationHm(int hours, int minutes) {
    return '$hours小时$minutes分';
  }

  @override
  String durationMs(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String durationS(int seconds) {
    return '$seconds秒';
  }

  @override
  String durationHms(int hours, int minutes, int seconds) {
    return '$hours小时$minutes分$seconds秒';
  }
}
