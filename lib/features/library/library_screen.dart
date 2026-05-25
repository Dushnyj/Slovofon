import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.library)),
      body: StatePlaceholder(
        iconAsset: AppIconAssets.navLibrary,
        title: strings.emptyLibrary,
        message: strings.mockDataNotice,
      ),
    );
  }
}
