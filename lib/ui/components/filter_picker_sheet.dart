import 'package:flutter/material.dart';

import '../adaptive/desktop_layout.dart';
import '../adaptive/television_layout.dart';

class FilterPickerSheet extends StatelessWidget {
  const FilterPickerSheet({required this.options, this.action, super.key});

  final List<Widget> options;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final television = TelevisionLayout.isActive(context);
    if (DesktopLayout.isActive(context) || television) {
      // Dialog already applies the keyboard insets. TV must not enter the
      // mobile branch below, which would subtract the same IME height twice.
      final prefix = television ? 'television' : 'desktop';
      final footer = action == null
          ? const SizedBox(height: 12)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                key: ValueKey('$prefix-picker-action'),
                width: double.infinity,
                child: action,
              ),
            );
      return LayoutBuilder(
        builder: (context, constraints) {
          final fontFactor = (MediaQuery.textScalerOf(context).scale(14) / 14)
              .clamp(1.0, 2.0);
          final minimumFixedHeight = television
              ? 56 + MediaQuery.textScalerOf(context).scale(24)
              : 160 * fontFactor;
          if (constraints.maxHeight < minimumFixedHeight) {
            // A touch keyboard may leave less room than a fixed action footer.
            // Scroll the action with the options rather than clipping either.
            return SingleChildScrollView(
              key: ValueKey('$prefix-picker-short-viewport'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options,
                    ),
                  ),
                  footer,
                ],
              ),
            );
          }
          return Column(
            key: ValueKey('$prefix-picker-body'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options,
                  ),
                ),
              ),
              footer,
            ],
          );
        },
      );
    }
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final availableHeight =
        (media.size.height - keyboardHeight - media.padding.top)
            .clamp(0.0, double.infinity)
            .toDouble();
    final maxHeight = (media.size.height * 0.72)
        .clamp(0.0, availableHeight)
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            key: const ValueKey('mobile-picker-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...options,
                if (action != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
