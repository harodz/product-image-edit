import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 220,
            child: ColoredBox(
              color: AppTokens.surfaceContainer,
              child: SafeArea(
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.spacingMd,
                        AppTokens.spacingMd,
                        AppTokens.spacingMd,
                        AppTokens.spacingSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTokens.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_fix_high,
                              size: 18,
                              color: AppTokens.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.navBrand,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTokens.outlineVariant.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: AppTokens.spacingSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacingSm,
                      ),
                      child: Column(
                        children: [
                          _NavButton(
                            label: l10n.navPipelineSettings,
                            icon: Icons.tune,
                            route: AppRouter.pipelineSettingsRoute,
                          ),
                          _NavButton(
                            label: l10n.navBatchDashboard,
                            icon: Icons.dashboard_outlined,
                            route: AppRouter.batchDashboardRoute,
                          ),
                          _NavButton(
                            label: l10n.navOutputGallery,
                            icon: Icons.photo_library_outlined,
                            route: AppRouter.outputReviewRoute,
                          ),
                          _NavButton(
                            label: l10n.navApiAccount,
                            icon: Icons.vpn_key_outlined,
                            route: AppRouter.apiSettingsRoute,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: AppTokens.outlineVariant.withValues(alpha: 0.15),
          ),
          Expanded(
            child: Container(
              color: AppTokens.surface,
              padding: const EdgeInsets.all(AppTokens.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: AppTokens.spacingLg),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name ?? '/';
    final active = current == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _navigate(context, current),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spacingMd,
            vertical: AppTokens.spacingSm,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppTokens.surfaceHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppTokens.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? AppTokens.primary
                    : AppTokens.onBackground.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? AppTokens.primary
                        : AppTokens.onBackground.withValues(alpha: 0.8),
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String currentRoute) {
    if (currentRoute == route) return;
    final pageBuilder = AppRouter.routes[route];
    if (pageBuilder == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: route),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, __) => pageBuilder(context),
      ),
    );
  }
}
