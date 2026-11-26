import 'dart:typed_data';

import 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart'
    as impl;

/// Hands [bytes] to the browser as a file download.
void saveBytes(
  Uint8List bytes,
  String fileName, {
  String mimeType = 'application/octet-stream',
}) => impl.saveBytes(bytes, fileName, mimeType);
