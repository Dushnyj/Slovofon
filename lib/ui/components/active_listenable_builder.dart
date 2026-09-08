import 'package:flutter/widgets.dart';

/// Pauses notifications in retained, offstage Navigator branches. Re-enabling
/// TickerMode rebuilds from the latest model without resetting route/scroll state.
/// Unlike a TickerMode around a ListenableBuilder this detaches its subscription.
class ActiveListenableBuilder extends StatefulWidget {
  const ActiveListenableBuilder({
    required this.listenable,
    required this.builder,
    this.child,
    super.key,
  });

  final Listenable listenable;
  final TransitionBuilder builder;
  final Widget? child;

  @override
  State<ActiveListenableBuilder> createState() =>
      _ActiveListenableBuilderState();
}

class _ActiveListenableBuilderState extends State<ActiveListenableBuilder> {
  bool _listening = false;

  void _changed() => setState(() {});

  void _setListening(bool enabled) {
    if (_listening == enabled) return;
    _listening = enabled;
    if (enabled) {
      widget.listenable.addListener(_changed);
    } else {
      widget.listenable.removeListener(_changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setListening(TickerMode.valuesOf(context).enabled);
  }

  @override
  void didUpdateWidget(ActiveListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable && _listening) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _setListening(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
