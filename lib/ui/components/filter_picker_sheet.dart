import 'package:flutter/material.dart';

class FilterPickerSheet extends StatelessWidget {
  const FilterPickerSheet({
    required this.options,
    required this.action,
    super.key,
  });

  final List<Widget> options;
  final Widget action;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: action),
            ],
          ),
        ),
      ),
    );
  }
}
