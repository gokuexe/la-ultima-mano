import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> exportResultCard(Uint8List bytes, String filename) async {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
  return null;
}
