import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import 'font_loader.dart';
import 'native_office.dart';

/// Word(docx) 转 PDF 服务 —— 本地优先。
///
/// Windows 端: 优先调用本机 WPS/Office COM 高保真转换;
/// 失败或非 Windows 端: 使用内置 docx 解析引擎
/// (支持段落/标题/加粗斜体下划线/字号颜色/对齐/图片/表格/列表,
/// 复杂排版(艺术字/文本框/公式/SmartArt)可能简化显示)。
class WordToPdfService {
  /// 仅支持 .docx；Windows 上 .doc 也交给 COM。
  static bool supports(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.docx')) return true;
    if (lower.endsWith('.doc')) return NativeOfficeConverter.isSupported;
    return false;
  }

  static Future<String> convert(
    String inputPath,
    String outputDir, {
    void Function(String stage)? onStage,
  }) async {
    final baseName = _baseName(inputPath);
    final sep = Platform.isWindows ? '\\' : '/';
    final expectedOut = '$outputDir$sep$baseName.pdf';

    // 1) 本机 COM 高保真转换
    if (NativeOfficeConverter.isSupported) {
      onStage?.call('正在调用本机 WPS/Office 转换…');
      final out = await NativeOfficeConverter.convert(inputPath, expectedOut);
      if (out != null) return out;
      onStage?.call('本机 Office 不可用，回退到内置引擎…');
    }

    if (!inputPath.toLowerCase().endsWith('.docx')) {
      throw Exception('手机端仅支持 .docx 文件（.doc 请先另存为 .docx）');
    }

    // 2) 内置引擎
    onStage?.call('正在解析文档…');
    final bytes = await File(inputPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXmlFile;
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        docXmlFile = f;
        break;
      }
    }
    if (docXmlFile == null) {
      throw Exception('无效的 docx 文件：缺少 document.xml');
    }
    final xmlDoc = XmlDocument.parse(_decodeUtf8(docXmlFile.content));

    // 关系映射 rId -> media 路径
    final rels = <String, String>{};
    for (final f in archive.files) {
      if (f.name == 'word/_rels/document.xml.rels') {
        final relDoc = XmlDocument.parse(_decodeUtf8(f.content));
        for (final rel in relDoc.descendantElements
            .where((e) => e.localName == 'Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          final type = rel.getAttribute('Type') ?? '';
          if (id != null && target != null && type.contains('/image')) {
            var path = target.replaceAll('\\', '/');
            if (!path.startsWith('word/')) path = 'word/$path';
            rels[id] = path;
          }
        }
        break;
      }
    }

    final appFont = await AppFont.load();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: appFont.font));
    final builder = _DocxRenderer(doc, archive, rels);
    final body = xmlDoc.descendantElements
        .firstWhere((e) => e.localName == 'body',
            orElse: () => xmlDoc.rootElement);
    builder.renderBody(body);

    onStage?.call('正在生成 PDF…');
    final out = _uniquePath(expectedOut);
    final saved = await doc.save();
    await File(out).writeAsBytes(saved);
    return out;
  }
}

// ---------------------------------------------------------------------------
// 内置 docx 渲染器
// ---------------------------------------------------------------------------
class _DocxRenderer {
  _DocxRenderer(this.doc, this.archive, this.rels);

  final pw.Document doc;
  final Archive archive;
  final Map<String, String> rels;

  static const contentWidth = 483.0; // A4 595pt - 2*56pt 边距
  static const contentHeight = 730.0;
  final PdfColor _black = const PdfColor(0, 0, 0);

  void renderBody(XmlElement body) {
    final widgets = <pw.Widget>[];
    for (final node in body.childElements) {
      switch (node.localName) {
        case 'p':
          widgets.addAll(_buildParagraph(node));
          break;
        case 'tbl':
          final t = _buildTable(node);
          if (t != null) widgets.add(t);
          break;
        default:
          break; // sectPr 等暂用默认 A4
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        build: (_) => widgets,
      ),
    );
  }

  // ---- 段落 ---------------------------------------------------------------
  List<pw.Widget> _buildParagraph(XmlElement p) {
    final pPr = _child(p, 'pPr');
    final style = pPr == null ? '' : (_textOf(_child(pPr, 'pStyle')) ?? '');
    final jc = pPr == null ? '' : (_textOf(_child(pPr, 'jc')) ?? '');
    final isList = pPr != null && _child(pPr, 'numPr') != null;

    var size = 12.0;
    var bold = false;
    if (style.startsWith('Heading')) {
      final level = int.tryParse(style.substring('Heading'.length)) ?? 1;
      size = switch (level) { 1 => 22.0, 2 => 18.0, 3 => 16.0, _ => 14.0 };
      bold = true;
    } else if (style == 'Title') {
      size = 26.0;
      bold = true;
    }

    // 段落级 rPr 的字号/加粗也生效（直接排版的文档常见）
    final pRpr = pPr == null ? null : _child(pPr, 'rPr');
    if (pRpr != null) {
      final sz = _szOf(pRpr);
      if (sz != null) size = sz;
      if (_child(pRpr, 'b') != null) bold = true;
    }

    final spans = <pw.TextSpan>[];
    final images = <pw.Widget>[];
    if (isList) {
      spans.add(pw.TextSpan(text: '•  '));
    }
    _walkRuns(p, spans, images, size, bold);

    final out = <pw.Widget>[];
    if (spans.any((s) => s.text!.isNotEmpty)) {
      pw.TextAlign align = pw.TextAlign.left;
      switch (jc) {
        case 'center':
          align = pw.TextAlign.center;
          break;
        case 'right':
          align = pw.TextAlign.right;
          break;
        case 'both':
          align = pw.TextAlign.justify;
          break;
      }
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.RichText(
            textAlign: align,
            text: pw.TextSpan(
              children: spans,
              style: pw.TextStyle(fontSize: size, color: _black),
            ),
          ),
        ),
      );
    }
    out.addAll(images);
    if (out.isEmpty) out.add(pw.SizedBox(height: 6));
    return out;
  }

  /// 递归收集 run，遇到嵌套表格(w:tbl)则停止（表格单独渲染，避免重复）
  void _walkRuns(XmlElement e, List<pw.TextSpan> spans,
      List<pw.Widget> images, double defSize, bool defBold) {
    for (final c in e.childElements) {
      switch (c.localName) {
        case 'r':
          _handleRun(c, spans, images, defSize, defBold);
          break;
        case 'tbl':
          break;
        case 'pPr':
        case 'rPr':
          break;
        default:
          _walkRuns(c, spans, images, defSize, defBold);
      }
    }
  }

  void _handleRun(XmlElement r, List<pw.TextSpan> spans,
      List<pw.Widget> images, double defSize, bool defBold) {
    final rPr = _child(r, 'rPr');
    final bold = defBold || (rPr != null && _child(rPr, 'b') != null);
    final italic = rPr != null && _child(rPr, 'i') != null;
    final underline = rPr != null && _child(rPr, 'u') != null;
    final sz = rPr == null ? null : _szOf(rPr);
    final fontSize = sz ?? defSize;
    var color = _black;
    if (rPr != null) {
      final c = _child(rPr, 'color');
      final hex = c == null ? null : (_attr(c, 'val'));
      if (hex != null && hex.length >= 6) {
        final rgb = int.tryParse(hex.substring(0, 6), radix: 16);
        if (rgb != null) {
          color = PdfColor(
            ((rgb >> 16) & 0xFF) / 255,
            ((rgb >> 8) & 0xFF) / 255,
            (rgb & 0xFF) / 255,
          );
        }
      }
    }

    // 图片
    for (final blip in r.descendantElements
        .where((e) => e.localName == 'blip')) {
      String? embed;
      for (final a in blip.attributes) {
        if (a.localName == 'embed') {
          embed = a.value;
          break;
        }
      }
      if (embed != null && rels.containsKey(embed)) {
        final img = _buildImage(rels[embed]!);
        if (img != null) images.add(img);
      }
    }

    // 文本
    final buf = StringBuffer();
    for (final node in r.childElements) {
      switch (node.localName) {
        case 't':
          buf.write(node.innerText);
          break;
        case 'tab':
          buf.write('    ');
          break;
        case 'br':
        case 'cr':
          buf.write('\n');
          break;
      }
    }
    final text = buf.toString();
    if (text.isNotEmpty) {
      spans.add(
        pw.TextSpan(
          text: text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            color: color,
            decoration:
                underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          ),
        ),
      );
    }
  }

  pw.Widget? _buildImage(String archivePath) {
    ArchiveFile? f;
    for (final file in archive.files) {
      if (file.isFile && file.name.replaceAll('\\', '/') == archivePath) {
        f = file;
        break;
      }
    }
    if (f == null) return null;
    final bytes = f.content;
    final lower = archivePath.toLowerCase();
    final isPng = lower.endsWith('.png');
    final isJpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
    try {
      Uint8List data = Uint8List.fromList(bytes);
      if (!isPng && !isJpg) {
        // pdf 包仅支持 png/jpeg；其余格式先转 jpg
        final decoded = im.decodeImage(bytes);
        if (decoded == null) return null;
        data = Uint8List.fromList(im.encodeJpg(decoded, quality: 90));
      }
      final info = im.decodeImage(data);
      if (info == null) return null;
      var w = info.width.toDouble();
      var h = info.height.toDouble();
      var scale = 1.0;
      if (w > contentWidth) scale = contentWidth / w;
      if (h * scale > contentHeight - 40) scale = (contentHeight - 40) / h;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Image(
          pw.MemoryImage(data),
          width: w * scale,
          height: h * scale,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ---- 表格 ---------------------------------------------------------------
  pw.Widget? _buildTable(XmlElement tbl) {
    final rows = tbl.childElements.where((e) => e.localName == 'tr').toList();
    if (rows.isEmpty) return null;
    final grid = <List<pw.Widget>>[];
    for (final tr in rows) {
      final cells = <pw.Widget>[];
      for (final tc in tr.childElements.where((e) => e.localName == 'tc')) {
        final cellChildren = <pw.Widget>[];
        for (final cp in tc.childElements.where((e) => e.localName == 'p')) {
          cellChildren.addAll(_buildParagraph(cp));
        }
        cells.add(
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: cellChildren.isEmpty
                  ? [pw.SizedBox(height: 10)]
                  : cellChildren,
            ),
          ),
        );
      }
      if (cells.isNotEmpty) grid.add(cells);
    }
    if (grid.isEmpty) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Table(
        border: pw.TableBorder.all(color: const PdfColor(0.7, 0.7, 0.7)),
        children: grid.map((r) => pw.TableRow(children: r)).toList(),
      ),
    );
  }

  // ---- 工具 ---------------------------------------------------------------
  double? _szOf(XmlElement rpr) {
    final sz = _child(rpr, 'sz');
    if (sz == null) return null;
    final v = _attr(sz, 'val');
    final half = int.tryParse(v ?? '');
    return half == null ? null : half / 2.0;
  }
}

XmlElement? _child(XmlElement e, String local) =>
    e.childElements.where((c) => c.localName == local).firstOrNull;

String? _textOf(XmlElement? e) => e?.innerText.trim();

String? _attr(XmlElement e, String local) {
  for (final a in e.attributes) {
    if (a.localName == local) return a.value;
  }
  return null;
}

String _baseName(String p) {
  final name = p.split(Platform.isWindows ? '\\' : '/').last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? name : name.substring(0, dot);
}

String _uniquePath(String path) {
  if (!File(path).existsSync()) return path;
  final sep = Platform.isWindows ? '\\' : '/';
  final dir = path.substring(0, path.lastIndexOf(sep));
  final name = path.substring(path.lastIndexOf(sep) + 1);
  final dot = name.lastIndexOf('.');
  final base = dot < 0 ? name : name.substring(0, dot);
  final ext = dot < 0 ? '' : name.substring(dot);
  var n = 1;
  var next = '$dir$sep$base($n)$ext';
  while (File(next).existsSync()) {
    next = '$dir$sep$base(${++n})$ext';
  }
  return next;
}

/// document.xml 为 UTF-8（可能带 BOM）
String _decodeUtf8(List<int> bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    b = b.sublist(3);
  }
  return utf8.decode(b, allowMalformed: true);
}
