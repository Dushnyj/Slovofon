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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final footer = Padding(
              padding: EdgeInsets.fromLTRB(16, action == null ? 0 : 8, 16, 16),
              child: action == null
                  ? const SizedBox.shrink()
                  : SizedBox(
                      key: const ValueKey('mobile-picker-action'),
                      width: double.infinity,
                      child: action,
                    ),
            );
            final optionsBody = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options,
              ),
            );
            final fontFactor = (MediaQuery.textScalerOf(context).scale(14) / 14)
                .clamp(1.0, 3.0);
            if (constraints.maxHeight < 120 * fontFactor) {
              return SingleChildScrollView(
                key: const ValueKey('mobile-picker-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [optionsBody, footer],
                ),
              );
            }
            // Use the actual route constraints (after the handle, safe area
            // and IME), not a second screen-percentage cap. Short pickers size
            // to content; long ones scroll with a permanently visible action.
            return Column(
              key: const ValueKey('mobile-picker-body'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('mobile-picker-scroll'),
                    child: optionsBody,
                  ),
                ),
                footer,
              ],
            );
          },
        ),
      ),
    );
  }
}
