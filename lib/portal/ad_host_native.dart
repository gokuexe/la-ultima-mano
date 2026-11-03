import 'ad_host.dart';

AdHost createAdHost() => _NoAds();

class _NoAds implements AdHost {
  @override
  bool get ready => false;
  @override
  void initialize(void Function(String) onEvent) {}
  @override
  bool showAd() => false;
}
