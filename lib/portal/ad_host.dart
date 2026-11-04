abstract interface class AdHost {
  bool get ready;
  void initialize(void Function(String) onEvent);
  bool showAd();
}
