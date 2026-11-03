import 'dart:js_interop';
import 'ad_host.dart';

@JS('lastHandPortal')
external _Bridge? get _bridge;
extension type _Bridge(JSObject _) implements JSObject {
  external JSBoolean get ready;
  external void setHandler(JSFunction callback);
  external JSBoolean showAd();
}
AdHost createAdHost() => _WebAds();

class _WebAds implements AdHost {
  @override
  bool get ready => _bridge?.ready.toDart ?? false;
  @override
  void initialize(void Function(String) onEvent) {
    _bridge?.setHandler(((JSString event) => onEvent(event.toDart)).toJS);
  }

  @override
  bool showAd() => _bridge?.showAd().toDart ?? false;
}
