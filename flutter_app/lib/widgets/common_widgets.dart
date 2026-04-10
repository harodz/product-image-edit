import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spacingMd),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTokens.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: AppTokens.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontSize: 11,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 0.5,
              color: AppTokens.onBackground.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}
