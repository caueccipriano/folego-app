import 'package:flutter/widgets.dart';

import 'realtime_invalidation.dart';
import 'realtime_session.dart';

typedef RealtimeChildBuilder = Widget Function(Key key);

class RealtimeRefreshView extends StatefulWidget {
  const RealtimeRefreshView({
    super.key,
    required this.domain,
    required this.identity,
    required this.builder,
    this.active = true,
  });

  final AppRealtimeDomain domain;
  final Object identity;
  final RealtimeChildBuilder builder;
  final bool active;

  @override
  State<RealtimeRefreshView> createState() => _RealtimeRefreshViewState();
}

class _RealtimeRefreshViewState extends State<RealtimeRefreshView> {
  RealtimeRefreshBinding? _binding;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant RealtimeRefreshView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain != widget.domain) {
      _binding?.dispose();
      _binding = null;
      _bind();
      return;
    }
    if (oldWidget.active != widget.active) {
      _binding?.setActive(widget.active);
    }
    if (oldWidget.identity != widget.identity) {
      setState(() => _revision += 1);
    }
  }

  void _bind() {
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator == null) return;
    _binding = coordinator.bind(
      domain: widget.domain,
      onRefresh: _refresh,
      active: widget.active,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _revision += 1);
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void dispose() {
    _binding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(ValueKey<Object>((widget.identity, _revision)));
  }
}
