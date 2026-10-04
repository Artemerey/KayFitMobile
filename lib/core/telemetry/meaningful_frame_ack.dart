import 'package:flutter/widgets.dart';

class MeaningfulFrameAck extends StatefulWidget {
  const MeaningfulFrameAck({
    super.key,
    required this.identity,
    required this.meaningful,
    required this.onRendered,
    required this.child,
  });

  final String identity;
  final bool meaningful;
  final VoidCallback onRendered;
  final Widget child;

  @override
  State<MeaningfulFrameAck> createState() => _MeaningfulFrameAckState();
}

class _MeaningfulFrameAckState extends State<MeaningfulFrameAck> {
  String? _acknowledgedIdentity;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant MeaningfulFrameAck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.meaningful != widget.meaningful)
      _schedule();
  }

  void _schedule() {
    if (!widget.meaningful || _acknowledgedIdentity == widget.identity) return;
    final identity = widget.identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.meaningful ||
          widget.identity != identity ||
          _acknowledgedIdentity == identity)
        return;
      _acknowledgedIdentity = identity;
      widget.onRendered();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
