// The browser's own download mechanism: a temporary link that is clicked
// and thrown away. `dart:html` is what the web build of this app targets
// (it is not built with --wasm).
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Downloads [content] as a file called [filename]. Returns true.
bool saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv',
}) {
  final blob = html.Blob(<Object>[content], '$mimeType;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
