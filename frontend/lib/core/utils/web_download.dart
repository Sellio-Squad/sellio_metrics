/// Sellio Metrics — Web Download Utility
///
/// Uses standard HTML anchor web injection to download a generated file.
library;

import 'dart:convert';
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebDownload {
  /// Triggers a browser file download using an invisible HTML anchor element.
  static void downloadFile(String content, String filename, String mimeType) {
    // Generate a secure base64 string
    final base64Content = base64Encode(utf8.encode(content));
    final uri = 'data:$mimeType;base64,$base64Content';

    // Create invisible anchor tag to trigger download
    final anchor = html.AnchorElement(href: uri)
      ..target = 'blank'
      ..download = filename;

    // Add, click, remove to avoid DOM pollution
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}
