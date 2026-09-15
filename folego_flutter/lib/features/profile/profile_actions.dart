class ProfileLogoutAction {
  ProfileLogoutAction(this._signOut);

  final Future<void> Function() _signOut;
  bool _running = false;

  bool get isRunning => _running;

  Future<bool> run() async {
    if (_running) {
      return false;
    }

    _running = true;
    try {
      await _signOut();
      return true;
    } finally {
      _running = false;
    }
  }
}
