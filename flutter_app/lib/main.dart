import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_router.dart';
import 'app/app_state.dart';
import 'services/macos_dragdrop_channel.dart';
import 'services/pipeline_runner.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final runner = PipelineRunner()..setApplicationSupportDirectory(support.path);
  runApp(
    ProductImageEditApp(
      runner: runner,
      applicationSupportPath: support.path,
    ),
  );
}

class ProductImageEditApp extends StatefulWidget {
  const ProductImageEditApp({
    required this.runner,
    required this.applicationSupportPath,
    this.locale,
    super.key,
  });

  final PipelineRunner runner;
  final String applicationSupportPath;

  /// When null, defaults to Chinese for production UI.
  final Locale? locale;

  @override
  State<ProductImageEditApp> createState() => _ProductImageEditAppState();
}

class _ProductImageEditAppState extends State<ProductImageEditApp> {
  late final AppState _appState;
  final MacOsDragDropChannel _dragDropChannel = MacOsDragDropChannel();

  @override
  void initState() {
    super.initState();
    _appState = AppState(
      widget.runner,
      applicationSupportPath: widget.applicationSupportPath,
    );
    if (Platform.isMacOS) {
      _dragDropChannel.bind(
        onPathDropped: (path) => unawaited(_appState.applyDroppedInputPath(path)),
      );
    }
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: _appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        theme: AppTheme.darkTheme,
        locale: widget.locale ?? const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: AppRouter.pipelineSettingsRoute,
        routes: AppRouter.routes,
      ),
    );
  }
}
