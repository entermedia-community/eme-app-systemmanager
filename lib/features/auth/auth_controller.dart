import 'package:eme_app_sdk/eme_app_sdk.dart'
    show AuthState, AuthStatus, EmUser;

export 'package:eme_app_sdk/eme_app_sdk.dart'
    show AuthState, AuthStatus, EmUser, authProvider;

/// Sign-in is handled by `eme_app_sdk` (emailed code, device key, signed
/// `X-token` headers). These helpers adapt its state to what the app reads.
extension AuthStateX on AuthState {
  /// Stable id of the signed-in user, or '' when signed out.
  String get userId => user?.username ?? '';

  /// True while the stored session is still being checked.
  bool get isRestoring =>
      status == AuthStatus.initial ||
      (status == AuthStatus.authenticating && user == null && email == null);
}

extension EmUserX on EmUser {
  String? get portrait => assetportrait;
}
