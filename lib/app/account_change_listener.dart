import 'package:flutter/widgets.dart';

import '../core/services/session_service.dart';
import '../core/utils/clear_providers.dart';

/// Resets every account-scoped provider whenever the signed-in account
/// changes — so no screen can keep showing, or keep adding to, the previous
/// account's data.
///
/// One listener instead of a reset call at each place an account can change:
/// login, logout, switch account, add account, the 2FA page, the
/// "session expired" sign-out and the launch-time access sign-out all move
/// [SessionService.currentSession], so all of them are covered, including any
/// path added later.
///
/// "The account" is `serverUrl|database|userId`: picking another company
/// within the same account is not an account change and resets nothing. A
/// switch that is refused never reaches [SessionService] (the session
/// manager holds provisional sessions back), so it resets nothing either.
class AccountChangeListener extends StatefulWidget {
  const AccountChangeListener({super.key, required this.child});

  final Widget child;

  @override
  State<AccountChangeListener> createState() => _AccountChangeListenerState();
}

class _AccountChangeListenerState extends State<AccountChangeListener> {
  final SessionService _sessionService = SessionService.instance;

  /// The account the providers currently hold data for. Unset until the
  /// session service has loaded the account restored at launch — that first
  /// account is where the app starts, not a change, so it resets nothing.
  String? _accountKey;
  bool _observed = false;

  @override
  void initState() {
    super.initState();
    _sessionService.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void dispose() {
    _sessionService.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!_sessionService.isInitialized) return;

    final session = _sessionService.currentSession;
    final key = session == null
        ? null
        : '${session.serverUrl}|${session.database}|${session.userId}';

    if (!_observed) {
      _observed = true;
      _accountKey = key;
      return;
    }
    if (key == _accountKey) return;

    _accountKey = key;
    // Not inline: this listener fires while the session service is still
    // notifying, and the reset notifies other providers in turn. A microtask
    // rather than a post-frame callback, which would wait for a frame that
    // nothing may have scheduled.
    Future.microtask(() {
      if (mounted) resetAllAppProviders(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
