import 'package:flutter_test/flutter_test.dart';

import 'package:word_pdf_tool/utils/format.dart';

void main() {
  test('formatBytes 输出人类可读体积', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.00 MB');
  });
}
