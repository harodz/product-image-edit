import 'package:flutter/material.dart';

import '../screens/api_settings_screen.dart';
import '../screens/batch_dashboard_screen.dart';
import '../screens/output_review_gallery_screen.dart';
import '../screens/pipeline_settings_screen.dart';

class AppRouter {
  static const pipelineSettingsRoute = '/';
  static const apiSettingsRoute = '/api';
  static const batchDashboardRoute = '/batch-dashboard';
  static const outputReviewRoute = '/output-review';

  static Map<String, WidgetBuilder> get routes {
    return {
      apiSettingsRoute: (_) => const ApiSettingsScreen(),
      batchDashboardRoute: (_) => const BatchDashboardScreen(),
      outputReviewRoute: (_) => const OutputReviewGalleryScreen(),
      pipelineSettingsRoute: (_) => const PipelineSettingsScreen(),
    };
  }
}
