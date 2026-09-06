import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source_access_policy.dart';
import 'source_settings_store.dart';

final sourceAccessPolicyProvider = Provider<SourceAccessPolicy>((ref) {
  // Keep the policy (and its consumers) stable on preference updates. The
  // policy reads live values from the notifier at each media-use boundary.
  return SourceAccessPolicy(ref.watch(sourceSettingsStoreProvider.notifier));
});
