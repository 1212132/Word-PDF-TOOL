import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';

import '../models.dart';
import 'font_loader.dart';

/// 压缩强度
enum CompressLevel {
  strong('高压缩（体积最小，清晰度略降）', 1.2, 55, 1200),
  balanced('均衡（推荐）', 1.6, 72, 1800),
  light('轻度（清晰度优先）', 2.2, 85, 2600);

  const CompressLevel(this.label, this.pdfScale, this.jpegQuality, this.maxEdge);
  final String label;
  final double pdfScale; // PDF 栅格化倍率（相对 72dpi）
  final int jpegQuality; // JPEG 质量
  final int maxEdge; // 图片最长边上限
}

// ---------------------------------------------------------------------------
// 图片压缩
// ---------------------------------------------------------------------------
class ImageCompressService {
  static Future<CompressResult> compress(
    String input,
    String outputDir,
    CompressLevel level,
  ) async {
    final before = await File(input).length();
    final bytes = await File(input).readAsBytes();
    im.Image? img;
    try {
      img = im.decodeImage(bytes);
    } catch (_) {}
    if (img == null) throw Exception('无法解析图片: $input');

    // 缩放
    final long = img.width > img.height ? img.width : img.height;
    if (long > level.maxEdge) {
      final s = level.maxEdge / long;
      img = im.copyResize(img, width: (img.width * s).round(), height: (img.height * s).round());
    }

    // 是否有透明通道（有则保留 PNG，否则转 JPG 获得更小体积）
    var hasAlpha = false;
    for (final px in img.data!) {
      if (px.a != 255) {
        hasAlpha = true;
        break;
      }
    }

    Uint8List out;
    String ext;
    if (hasAlpha && input.toLowerCase().endsWith('.png')) {
      out = Uint8List.fromList(im.encodePng(img, level: 8));
      ext = '.png';
    } else {
      out = Uint8List.fromList(im.encodeJpg(img, quality: level.jpegQuality));
      ext = '.jpg';
    }

    final outPath = _outPath(outputDir, _base(input), '_压缩', ext);
    await File(outPath).writeAsBytes(out);
    return CompressResult(
      outputPath: outPath,
      beforeSize: before,
      afterSize: out.length,
      warning: out.length >= before ? '原图已较小，压缩收益有限' : null,
    );
  }
}

// ---------------------------------------------------------------------------
// PDF 压缩（栅格化重建）
// ---------------------------------------------------------------------------
class PdfCompressService {
  static Future<CompressResult> compress(
    String input,
    String outputDir,
    CompressLevel level,
  ) async {
    final before = await File(input).length();
    final src = await PdfDocument.openFile(input);
    final doc = pw.Document();
    final pageCount = src.pagesCount;

    for (var i = 1; i <= pageCount; i++) {
      final page = await src.getPage(i);
      final w = page.width * level.pdfScale;
      final h = page.height * level.pdfScale;
      final rendered = await page.render(
        width: w,
        height: h,
        format: PdfPageImageFormat.jpeg,
        quality: level.jpegQuality,
      );
      if (rendered != null) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            build: (_) => pw.Image(
              pw.MemoryImage(rendered.bytes),
              width: page.width,
              height: page.height,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }
      await page.close();
    }
    await src.close();

    final out = _outPath(outputDir, _base(input), '_压缩', '.pdf');
    final saved = await doc.save();
    await File(out).writeAsBytes(saved);

    return CompressResult(
      outputPath: out,
      beforeSize: before,
      afterSize: saved.length,
      warning: saved.length >= before
          ? '该 PDF 以文字为主且已高度优化，栅格化后可能不减反增，建议保留原文件'
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Word 压缩（重压缩 docx 内嵌图片 + zip 重新打包）
// ---------------------------------------------------------------------------
class WordCompressService {
  static Future<CompressResult> compress(
    String input,
    String outputDir,
    CompressLevel level,
  ) async {
    if (!input.toLowerCase().endsWith('.docx')) {
      throw Exception('仅支持 .docx 文件（.doc 请先另存为 .docx）');
    }
    final before = await File(input).length();
    final bytes = await File(input).readAsBytes();
    final src = ZipDecoder().decodeBytes(bytes);
    final out = Archive();
    var mediaChanged = 0;

    for (final f in src.files) {
      if (f.isFile) {
        var data = f.content;
        final lower = f.name.toLowerCase();
        final isMedia = lower.startsWith('word/media/') &&
            (lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg'));
        if (isMedia) {
          final compressed = _compressMedia(data, lower, level);
          if (compressed != null && compressed.length < data.length) {
            data = compressed;
            mediaChanged++;
          }
        }
        // 保持原始文件名与格式，确保 docx 内部引用([Content_Types].xml/rels)不被破坏
        out.addFile(ArchiveFile(f.name, data.length, Uint8List.fromList(data)));
      }
    }

    final encoded = ZipEncoder().encode(out);

    final outPath = _outPath(outputDir, _base(input), '_压缩', '.docx');
    await File(outPath).writeAsBytes(encoded);

    return CompressResult(
      outputPath: outPath,
      beforeSize: before,
      afterSize: encoded.length,
      warning: mediaChanged == 0
          ? '文档未包含可压缩的图片，收益主要来自重新打包'
          : '已重压缩 $mediaChanged 张内嵌图片',
    );
  }

  /// 重压缩单张内嵌图片，保持原格式返回（null 表示无法处理或不划算）
  static Uint8List? _compressMedia(Uint8List data, String lower, CompressLevel level) {
    try {
      im.Image? img;
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg')) {
        img = im.decodeImage(data);
      }
      if (img == null) return null;

      final long = img.width > img.height ? img.width : img.height;
      if (long > level.maxEdge) {
        final s = level.maxEdge / long;
        img = im.copyResize(img, width: (img.width * s).round(), height: (img.height * s).round());
      }

      if (lower.endsWith('.png')) {
        // PNG 有透明通道则保留 PNG（仅重编码）；无透明也可转 JPEG 体积更小，
        // 但为不破坏引用关系，保持 PNG 格式
        return Uint8List.fromList(im.encodePng(img, level: 9));
      }
      return Uint8List.fromList(im.encodeJpg(img, quality: level.jpegQuality));
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// 通用工具
// ---------------------------------------------------------------------------
String _base(String p) {
  final name = p.split(Platform.isWindows ? '\\' : '/').last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? name : name.substring(0, dot);
}

String _outPath(String dir, String base, String tag, String ext) {
  final sep = Platform.isWindows ? '\\' : '/';
  var path = '$dir$sep$base$tag$ext';
  var n = 1;
  while (File(path).existsSync()) {
    path = '$dir$sep$base$tag(${++n})$ext';
  }
  return path;
}

/// 供 ImageToPdfService 复用（theme 字体）
Future<pw.ThemeData> pdfTheme() async =>
    pw.ThemeData.withFont(base: (await AppFont.load()).font);
