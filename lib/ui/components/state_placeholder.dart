import '../motion/motion_progress_indicator.dart';
import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

class StatePlaceholder extends StatelessWidget {
  const StatePlaceholder({
    required this.iconAsset,
    required this.title,
    this.message,
    this.loading = false,
    this.isError = false,
    super.key,
  });

  const StatePlaceholder.loading({required this.title, this.message, super.key})
    : iconAsset = AppIconAssets.downloading,
      loading = true,
      isError = false;

  const StatePlaceholder.empty({required this.title, this.message, super.key})
    : iconAsset = AppIconAssets.systemInfo,
      loading = false,
      isError = false;

  const StatePlaceholder.error({required this.title, this.message, super.key})
    : iconAsset = AppIconAssets.systemWarning,
      loading = false,
      isError = true;

  final String iconAsset;
  final String title;
  final String? message;
  final bool loading;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const AppCircularProgressIndicator()
              else
                AppIcon(
                  iconAsset,
                  size: 48,
                  color: isError ? colorScheme.error : colorScheme.primary,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
