import 'package:flutter/material.dart';
import '../../core/services/offline_error_handler.dart';

/// A wrapper widget that initializes and updates the global [OfflineErrorHandler] to monitor network status.
class ConnectivityListenerWidget extends StatefulWidget {
  final Widget child;

  const ConnectivityListenerWidget({super.key, required this.child});

  @override
  State<ConnectivityListenerWidget> createState() =>
      _ConnectivityListenerWidgetState();
}

class _ConnectivityListenerWidgetState
    extends State<ConnectivityListenerWidget> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OfflineErrorHandler.instance.initialize(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    OfflineErrorHandler.instance.updateContext(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
