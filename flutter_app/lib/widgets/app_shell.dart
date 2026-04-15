import 'package:flutter/material.dart';

import '../app/app_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';

// Width at which the sidebar collapses to icon-only rail.
const _kCollapseBreakpoint = 640.0;
const _kSidebarWidth = 220.0;
const _kSidebarCollapsedWidth = 56.0;

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < _kCollapseBreakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(l10n: l10n, collapsed: collapsed),
              Container(
                width: 1,
                color: AppTokens.outlineVariant.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _ContentArea(
                  title: title,
                  collapsed: collapsed,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.l10n, required this.collapsed});

  final AppLocalizations l10n;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? _kSidebarCollapsedWidth : _kSidebarWidth,
      child: ColoredBox(
        color: AppTokens.surfaceContainer,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandHeader(l10n: l10n, collapsed: collapsed),
              Divider(
                height: 1,
                color: AppTokens.outlineVariant.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppTokens.spacingSm),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 4 : AppTokens.spacingSm,
                ),
                child: Column(
                  children: [
                    _NavButton(
                      label: l10n.navPipelineSettings,
                      icon: Icons.tune,
                      route: AppRouter.pipelineSettingsRoute,
                      collapsed: collapsed,
                    ),
                    _NavButton(
                      label: l10n.navBatchDashboard,
                      icon: Icons.dashboard_outlined,
                      route: AppRouter.batchDashboardRoute,
                      collapsed: collapsed,
                    ),
                    _NavButton(
                      label: l10n.navOutputGallery,
                      icon: Icons.photo_library_outlined,
                      route: AppRouter.outputReviewRoute,
                      collapsed: collapsed,
                    ),
                    _NavButton(
                      label: l10n.navApiAccount,
                      icon: Icons.vpn_key_outlined,
                      route: AppRouter.apiSettingsRoute,
                      collapsed: collapsed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.l10n, required this.collapsed});

  final AppLocalizations l10n;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
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
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spacingMd),
        child: Center(child: logo),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spacingMd,
        AppTokens.spacingMd,
        AppTokens.spacingMd,
        AppTokens.spacingSm,
      ),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.navBrand,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content area ───────────────────────────────────────────────────────────────

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.title,
    required this.collapsed,
    required this.child,
  });

  final String title;
  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = collapsed ? AppTokens.spacingMd : AppTokens.spacingLg;
    return Container(
      color: AppTokens.surface,
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: collapsed ? AppTokens.spacingMd : AppTokens.spacingLg),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Nav button ─────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.route,
    required this.collapsed,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.of(context)?.settings.name ?? '/';
    final active = current == route;

    final iconWidget = Icon(
      icon,
      size: 16,
      color: active
          ? AppTokens.primary
          : AppTokens.onBackground.withValues(alpha: 0.55),
    );

    final decoration = BoxDecoration(
      color: active ? AppTokens.surfaceHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: active
            ? AppTokens.primary.withValues(alpha: 0.25)
            : Colors.transparent,
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: InkWell(
            onTap: () => _navigate(context, current),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: decoration,
              alignment: Alignment.center,
              child: iconWidget,
            ),
          ),
        ),
      );
    }

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
          decoration: decoration,
          child: Row(
            children: [
              iconWidget,
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
