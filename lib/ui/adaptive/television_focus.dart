import 'package:flutter/material.dart';

import 'television_layout.dart';

/// Only a shell branch route may traverse out to the surrounding TV chrome.
/// A FocusTraversalGroup alone cannot cross a Navigator route's default stop
/// edge. Dialogs and standalone routes deliberately retain their own scopes.
class TelevisionBranchFocus extends StatefulWidget {
  const TelevisionBranchFocus({required this.child, super.key});
  final Widget child;

  @override
  State<TelevisionBranchFocus> createState() => _TelevisionBranchFocusState();
}

class _TelevisionBranchFocusState extends State<TelevisionBranchFocus> {
  FocusScopeNode? _scope;
  TraversalEdgeBehavior? _previous;
  bool? _previousSkipTraversal;

  void _restore() {
    final scope = _scope;
    if (scope != null &&
        scope.directionalTraversalEdgeBehavior ==
            TraversalEdgeBehavior.parentScope) {
      scope.directionalTraversalEdgeBehavior = _previous!;
    }
    if (scope != null && _previousSkipTraversal != null) {
      scope.skipTraversal = _previousSkipTraversal!;
    }
    _scope = null;
    _previous = null;
    _previousSkipTraversal = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TelevisionLayout.isActive(context)) {
      _restore();
      return;
    }
    final scope = FocusScope.of(context);
    if (!identical(scope, _scope)) {
      _restore();
      _scope = scope;
      _previous = scope.directionalTraversalEdgeBehavior;
      _previousSkipTraversal = scope.skipTraversal;
    }
    scope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.parentScope;
    // The route scope's large rectangle must not itself compete with the
    // transport below it. Focusing that scope simply restores its last child,
    // producing an apparent Down trap. Its actual descendants still traverse.
    scope.skipTraversal = true;
  }

  @override
  void dispose() {
    _restore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A remote-controlled screen must not lose its highlight after IME input.
/// Restore the prior global strategy once the last TV viewport is removed.
abstract final class TelevisionFocusHighlight {
  static int _users = 0;
  static FocusHighlightStrategy? _previous;

  static void acquire() {
    if (_users++ == 0) _previous ??= FocusManager.instance.highlightStrategy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_users > 0) {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
      }
    });
  }

  static void release() {
    assert(_users > 0);
    _users--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_users == 0 && _previous != null) {
        if (FocusManager.instance.highlightStrategy ==
            FocusHighlightStrategy.alwaysTraditional) {
          FocusManager.instance.highlightStrategy = _previous!;
        }
        _previous = null;
      }
    });
  }
}
