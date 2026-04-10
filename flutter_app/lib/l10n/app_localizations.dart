import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Image Editor'**
  String get appTitle;

  /// No description provided for @navBrand.
  ///
  /// In en, this message translates to:
  /// **'Product\nPipeline'**
  String get navBrand;

  /// No description provided for @navPipelineSettings.
  ///
  /// In en, this message translates to:
  /// **'Pipeline Settings'**
  String get navPipelineSettings;

  /// No description provided for @navBatchDashboard.
  ///
  /// In en, this message translates to:
  /// **'Batch Dashboard'**
  String get navBatchDashboard;

  /// No description provided for @navOutputGallery.
  ///
  /// In en, this message translates to:
  /// **'Output Gallery'**
  String get navOutputGallery;

  /// No description provided for @navApiAccount.
  ///
  /// In en, this message translates to:
  /// **'API & account'**
  String get navApiAccount;

  /// No description provided for @dropFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Drop folder or image, or browse'**
  String get dropFolderHint;

  /// No description provided for @selectImages.
  ///
  /// In en, this message translates to:
  /// **'Select Image(s)'**
  String get selectImages;

  /// No description provided for @browseFolder.
  ///
  /// In en, this message translates to:
  /// **'Browse Folder'**
  String get browseFolder;

  /// No description provided for @dialogSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select folder'**
  String get dialogSelectFolder;

  /// No description provided for @dialogSelectImages.
  ///
  /// In en, this message translates to:
  /// **'Select image(s)'**
  String get dialogSelectImages;

  /// No description provided for @screenPipelineSettings.
  ///
  /// In en, this message translates to:
  /// **'Pipeline Settings'**
  String get screenPipelineSettings;

  /// No description provided for @sectionBatchConfiguration.
  ///
  /// In en, this message translates to:
  /// **'BATCH CONFIGURATION'**
  String get sectionBatchConfiguration;

  /// No description provided for @inputFolderOrImage.
  ///
  /// In en, this message translates to:
  /// **'Input folder or image'**
  String get inputFolderOrImage;

  /// No description provided for @outputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Output Directory'**
  String get outputDirectory;

  /// No description provided for @sectionExecutionParameters.
  ///
  /// In en, this message translates to:
  /// **'EXECUTION PARAMETERS'**
  String get sectionExecutionParameters;

  /// No description provided for @flagWorkers.
  ///
  /// In en, this message translates to:
  /// **'--workers'**
  String get flagWorkers;

  /// No description provided for @workersMinLabel.
  ///
  /// In en, this message translates to:
  /// **'1 JOB'**
  String get workersMinLabel;

  /// No description provided for @workersMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'64 JOBS (MAX)'**
  String get workersMaxLabel;

  /// No description provided for @flagMaxApiRetries.
  ///
  /// In en, this message translates to:
  /// **'--max-api-retries'**
  String get flagMaxApiRetries;

  /// No description provided for @maxApiRetriesHelp.
  ///
  /// In en, this message translates to:
  /// **'Maximum attempts per file before flagging failure.'**
  String get maxApiRetriesHelp;

  /// No description provided for @flagKeepRaw.
  ///
  /// In en, this message translates to:
  /// **'--keep-raw'**
  String get flagKeepRaw;

  /// No description provided for @keepRawSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preserve original buffers alongside output.'**
  String get keepRawSubtitle;

  /// No description provided for @flagFailFast.
  ///
  /// In en, this message translates to:
  /// **'--fail-fast'**
  String get flagFailFast;

  /// No description provided for @failFastSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Abort pipeline on first error.'**
  String get failFastSubtitle;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @promptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get promptLabel;

  /// No description provided for @useResponseModalities.
  ///
  /// In en, this message translates to:
  /// **'Use response modalities'**
  String get useResponseModalities;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed'**
  String get copyFailed;

  /// No description provided for @noProgress.
  ///
  /// In en, this message translates to:
  /// **'No progress'**
  String get noProgress;

  /// No description provided for @pipelineRunning.
  ///
  /// In en, this message translates to:
  /// **'Pipeline running'**
  String get pipelineRunning;

  /// No description provided for @allSystemsOperational.
  ///
  /// In en, this message translates to:
  /// **'All systems operational'**
  String get allSystemsOperational;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @previewCommand.
  ///
  /// In en, this message translates to:
  /// **'Preview Command'**
  String get previewCommand;

  /// No description provided for @runningEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get runningEllipsis;

  /// No description provided for @runPipeline.
  ///
  /// In en, this message translates to:
  /// **'Run Pipeline'**
  String get runPipeline;

  /// No description provided for @commandPreview.
  ///
  /// In en, this message translates to:
  /// **'Command Preview'**
  String get commandPreview;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sectionNeuralModel.
  ///
  /// In en, this message translates to:
  /// **'NEURAL MODEL'**
  String get sectionNeuralModel;

  /// No description provided for @modelDescRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended · High Accuracy'**
  String get modelDescRecommended;

  /// No description provided for @modelDescFast.
  ///
  /// In en, this message translates to:
  /// **'Fast Inference'**
  String get modelDescFast;

  /// No description provided for @modelDescLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy · Stable'**
  String get modelDescLegacy;

  /// No description provided for @customModel.
  ///
  /// In en, this message translates to:
  /// **'Custom model'**
  String get customModel;

  /// No description provided for @activeBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeBadge;

  /// No description provided for @currentProfile.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PROFILE'**
  String get currentProfile;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get statusRunning;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @profileWorkers.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get profileWorkers;

  /// No description provided for @profileRetries.
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get profileRetries;

  /// No description provided for @profileOutputImages.
  ///
  /// In en, this message translates to:
  /// **'Output images'**
  String get profileOutputImages;

  /// No description provided for @tipsHeading.
  ///
  /// In en, this message translates to:
  /// **'TIPS'**
  String get tipsHeading;

  /// No description provided for @tipsBody.
  ///
  /// In en, this message translates to:
  /// **'• Lower workers if you see repeated 429 errors.\n• Re-run to resume from checkpoint.\n• Set API key in API & account.'**
  String get tipsBody;

  /// No description provided for @screenApiAccount.
  ///
  /// In en, this message translates to:
  /// **'API & account'**
  String get screenApiAccount;

  /// No description provided for @geminiApiKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Gemini API key'**
  String get geminiApiKeyTitle;

  /// No description provided for @geminiApiKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Saved automatically to your app data folder as you type (and when you leave this field). It is not embedded in the app bundle.'**
  String get geminiApiKeyDescription;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'GEMINI_API_KEY'**
  String get apiKeyHint;

  /// No description provided for @showKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get showKey;

  /// No description provided for @hideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get hideKey;

  /// No description provided for @lastSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Last saved: {time}'**
  String lastSavedAt(String time);

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key saved'**
  String get apiKeySaved;

  /// No description provided for @saveNow.
  ///
  /// In en, this message translates to:
  /// **'Save now'**
  String get saveNow;

  /// No description provided for @storagePath.
  ///
  /// In en, this message translates to:
  /// **'Storage path'**
  String get storagePath;

  /// No description provided for @screenOutputGallery.
  ///
  /// In en, this message translates to:
  /// **'Output Review Gallery'**
  String get screenOutputGallery;

  /// No description provided for @outputItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String outputItemCount(int count);

  /// No description provided for @processedLabel.
  ///
  /// In en, this message translates to:
  /// **'processed'**
  String get processedLabel;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get filterApproved;

  /// No description provided for @filterNeedsEdit.
  ///
  /// In en, this message translates to:
  /// **'Needs Edit'**
  String get filterNeedsEdit;

  /// No description provided for @filterRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get filterRejected;

  /// No description provided for @filterUnreviewed.
  ///
  /// In en, this message translates to:
  /// **'Unreviewed'**
  String get filterUnreviewed;

  /// No description provided for @tooltipSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get tooltipSelectAll;

  /// No description provided for @tooltipDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get tooltipDeselectAll;

  /// No description provided for @tooltipRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tooltipRefresh;

  /// No description provided for @noImagesInView.
  ///
  /// In en, this message translates to:
  /// **'No images in this view.'**
  String get noImagesInView;

  /// No description provided for @itemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item selected} other{{count} items selected}}'**
  String itemsSelected(int count);

  /// No description provided for @rejectSelected.
  ///
  /// In en, this message translates to:
  /// **'Reject Selected'**
  String get rejectSelected;

  /// No description provided for @approveSelected.
  ///
  /// In en, this message translates to:
  /// **'Approve Selected'**
  String get approveSelected;

  /// No description provided for @screenBatchDashboard.
  ///
  /// In en, this message translates to:
  /// **'Batch Dashboard'**
  String get screenBatchDashboard;

  /// No description provided for @metricEta.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get metricEta;

  /// No description provided for @emDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get emDash;

  /// No description provided for @metricThroughput.
  ///
  /// In en, this message translates to:
  /// **'Throughput'**
  String get metricThroughput;

  /// No description provided for @perMinute.
  ///
  /// In en, this message translates to:
  /// **'/min'**
  String get perMinute;

  /// No description provided for @metricSuccessRate.
  ///
  /// In en, this message translates to:
  /// **'Success Rate'**
  String get metricSuccessRate;

  /// No description provided for @imagesProgressNone.
  ///
  /// In en, this message translates to:
  /// **'{done} images'**
  String imagesProgressNone(int done);

  /// No description provided for @imagesProgressTotal.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} images'**
  String imagesProgressTotal(int done, int total);

  /// No description provided for @geminiActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Gemini'**
  String geminiActiveLabel(int count);

  /// No description provided for @cleanupActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Cleanup'**
  String cleanupActiveLabel(int count);

  /// No description provided for @backoffSeconds.
  ///
  /// In en, this message translates to:
  /// **'Backoff: {seconds}s'**
  String backoffSeconds(int seconds);

  /// No description provided for @workersActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'{active}/{total} Workers Active'**
  String workersActiveLabel(int active, int total);

  /// No description provided for @rateLimitWaiting.
  ///
  /// In en, this message translates to:
  /// **'Rate limit — waiting'**
  String get rateLimitWaiting;

  /// No description provided for @gridFilename.
  ///
  /// In en, this message translates to:
  /// **'FILENAME'**
  String get gridFilename;

  /// No description provided for @gridGemini.
  ///
  /// In en, this message translates to:
  /// **'GEMINI'**
  String get gridGemini;

  /// No description provided for @gridCleanup.
  ///
  /// In en, this message translates to:
  /// **'CLEANUP'**
  String get gridCleanup;

  /// No description provided for @gridLatency.
  ///
  /// In en, this message translates to:
  /// **'LATENCY'**
  String get gridLatency;

  /// No description provided for @gridActions.
  ///
  /// In en, this message translates to:
  /// **'ACTIONS'**
  String get gridActions;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @logsForFile.
  ///
  /// In en, this message translates to:
  /// **'Logs — {fileName}'**
  String logsForFile(String fileName);

  /// No description provided for @noLogEntriesForFile.
  ///
  /// In en, this message translates to:
  /// **'No log entries for this file.'**
  String get noLogEntriesForFile;

  /// No description provided for @emptyWaitingFirstImage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first image...'**
  String get emptyWaitingFirstImage;

  /// No description provided for @emptyNoActiveRun.
  ///
  /// In en, this message translates to:
  /// **'No active run'**
  String get emptyNoActiveRun;

  /// No description provided for @emptyWaitingFirstImageSub.
  ///
  /// In en, this message translates to:
  /// **'Images will appear here as they are processed.'**
  String get emptyWaitingFirstImageSub;

  /// No description provided for @emptyNoActiveRunSub.
  ///
  /// In en, this message translates to:
  /// **'Run a pipeline from Pipeline Settings to begin. If the input folder has files but this list is empty, they are skipped until you mark them needs edit or rejected in the Output Gallery (see _pipeline_image_state.json).'**
  String get emptyNoActiveRunSub;

  /// No description provided for @failuresHeading.
  ///
  /// In en, this message translates to:
  /// **'Failures'**
  String get failuresHeading;

  /// No description provided for @errorGroupSafetyFilter.
  ///
  /// In en, this message translates to:
  /// **'Safety Filter'**
  String get errorGroupSafetyFilter;

  /// No description provided for @errorGroupRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Rate Limit'**
  String get errorGroupRateLimit;

  /// No description provided for @errorGroupApiError.
  ///
  /// In en, this message translates to:
  /// **'API Error'**
  String get errorGroupApiError;

  /// No description provided for @retryAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry All Failed'**
  String get retryAllFailed;

  /// No description provided for @openOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Output Folder'**
  String get openOutputFolder;

  /// No description provided for @workersLabel.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get workersLabel;

  /// No description provided for @takesEffectNextRetry.
  ///
  /// In en, this message translates to:
  /// **'Takes effect on next retry'**
  String get takesEffectNextRetry;

  /// No description provided for @consoleHeading.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get consoleHeading;

  /// No description provided for @consoleErrorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String consoleErrorCount(int count);

  /// No description provided for @noOutputYet.
  ///
  /// In en, this message translates to:
  /// **'No output yet.'**
  String get noOutputYet;

  /// No description provided for @batchComplete.
  ///
  /// In en, this message translates to:
  /// **'Batch Complete'**
  String get batchComplete;

  /// No description provided for @batchCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} images processed{durationPart}'**
  String batchCompleteSubtitle(int done, int total, String durationPart);

  /// No description provided for @durationPartIn.
  ///
  /// In en, this message translates to:
  /// **' in {duration}'**
  String durationPartIn(String duration);

  /// No description provided for @spaceSaved.
  ///
  /// In en, this message translates to:
  /// **'Space saved: {size}'**
  String spaceSaved(String size);

  /// No description provided for @startNewBatch.
  ///
  /// In en, this message translates to:
  /// **'Start New Batch'**
  String get startNewBatch;

  /// No description provided for @durationHm.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHm(int hours, int minutes);

  /// No description provided for @durationMs.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String durationMs(int minutes, int seconds);

  /// No description provided for @durationS.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationS(int seconds);

  /// No description provided for @durationHms.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m {seconds}s'**
  String durationHms(int hours, int minutes, int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
