import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../ui/components/state_placeholder.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.downloads)),
      body: StatePlaceholder(
        icon: Icons.download_for_offline_rounded,
        title: strings.emptyDownloads,
        message: strings.mockDataNotice,
      ),
    );
  }
}
