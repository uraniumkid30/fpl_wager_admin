/// Saving a file is only possible in a web browser. Returns false so the
/// caller can fall back to the clipboard.
bool saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv',
}) =>
    false;
