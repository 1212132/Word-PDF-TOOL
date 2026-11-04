import 'dart:io';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'font_loader.dart';

/// 图片转 PDF 服务
class ImageToPdfOptions {
  const ImageToPdfOptions({
    this.pageSizeMode = PageSizeMode.a4,
    this.marginMm = 10,
    this.dpi = 96,
  });

  /// a4: 所有图统一放入 A4 页面；auto: 页面尺寸跟随图片
  final PageSizeMode pageSizeMode;
  final double marginMm; // A4 模式页边距（毫米）
  final int dpi; // auto 模式下 1px = 72/dpi 英寸
}

enum PageSizeMode { a4, auto }

class ImageToPdfService {
  /// [paths] 已排序的图片路径列表，返回输出 PDF 路径
  static Future<String> convert(
    List<String> paths,
    String outputDir, {
    ImageToPdfOptions options = const ImageToPdfOptions(),
    void Function(int done, int total)? onProgress,
  }) async {
    final appFont = await AppFont.load();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: appFont.font));
    final margin = options.marginMm * 72 / 25.4;

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final bytes = await File(path).readAsBytes();
      im.Image? info;
      try {
        info = im.decodeImage(bytes);
      } catch (_) {
        info = null;
      }
      if (info == null) {
        throw Exception('无法解析图片: ${_fileName(path)}');
      }
      final w = info.width;
      final h = info.height;
      final decoded = im.encodeJpg(info, quality: 92);
      final img = pw.Image(
        pw.MemoryImage(decoded),
        fit: pw.BoxFit.contain,
      );

      if (options.pageSizeMode == PageSizeMode.auto) {
        final pageW = w * 72 / options.dpi;
        final pageH = h * 72 / options.dpi;
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageW, pageH),
            build: (_) => pw.Center(child: img),
          ),
        );
      } else {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(margin),
            build: (_) => pw.Center(child: img),
          ),
        );
      }
      onProgress?.call(i + 1, paths.length);
    }

    final out = _outputPath(outputDir, '图片合并', '.pdf');
    await doc.save().then((b) => File(out).writeAsBytes(b));
    return out;
  }
}

String _fileName(String p) => p.split(Platform.isWindows ? '\\' : '/').last;

String _outputPath(String dir, String base, String ext) {
  final sep = Platform.isWindows ? '\\' : '/';
  var path = '$dir$sep$base$ext';
  var n = 1;
  while (File(path).existsSync()) {
    path = '$dir$sep$base(${++n})$ext';
  }
  return path;
}
