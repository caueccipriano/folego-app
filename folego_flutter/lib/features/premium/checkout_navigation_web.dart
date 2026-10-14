import 'dart:js_interop';

@JS('location.assign')
external void _navigate(JSString url);

bool openSandboxCheckout(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' ||
      uri.host != 'sandbox.asaas.com' || uri.userInfo.isNotEmpty) {
    return false;
  }
  _navigate(url.toJS);
  return true;
}
