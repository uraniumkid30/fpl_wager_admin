/// Saving a text file (a CSV export) to the administrator's computer.
///
/// In a web browser the file is downloaded. Elsewhere there is no download
/// folder the app can write to without extra packages, so [saveTextFile]
/// returns false and the caller copies the text to the clipboard instead.
library;

export 'save_file_stub.dart' if (dart.library.html) 'save_file_web.dart';
