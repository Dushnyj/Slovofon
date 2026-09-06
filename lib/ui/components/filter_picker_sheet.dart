import 'package:flutter/material.dart';

import '../adaptive/desktop_layout.dart';

class FilterPickerSheet extends StatelessWidget {
  const FilterPickerSheet({required this.options, this.action, super.key});

  final List<Widget> options;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (DesktopLayout.isActive(context)) {
      final footer = action == null
          ? const SizedBox(height: 12)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                key: const ValueKey('desktop-picker-action'),
                width: double.infinity,
                child: action,
              ),
            );
      return LayoutBuilder(
        builder: (context, constraints) {
          final fontFactor = (MediaQuery.textScalerOf(context).scale(14) / 14)
              .clamp(1.0, 2.0);
          if (constraints.maxHeight < 160 * fontFactor) {
            // A touch keyboard may leave less room than a fixed action footer.
            // Scroll the action with the options rather than clipping either.
            return SingleChildScrollView(
              key: const ValueKey('desktop-picker-short-viewport'),
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
            key: const ValueKey('desktop-picker-body'),
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
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
    );
  }
}
