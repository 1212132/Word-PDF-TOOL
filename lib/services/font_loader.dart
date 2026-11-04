import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// PDF 渲染所需 CJK 字体加载器。
///
/// 策略（全部为运行时读取，不打包字体，安装包保持精简）：
///  1. Windows: msyh.ttc / simhei.ttf / simsun.ttc（TTC 通过切片提取第一个字体）
///  2. Android: NotoSansCJK*.ttc（切片）/ DroidSansFallback*.ttf
///  3. 找不到时返回 null，调用方需提示"中文可能无法显示"。
class AppFont {
  AppFont._(this.font, this.name);
  final pw.Font? font;
  final String name;

  static AppFont? _cached;

  static Future<AppFont> load() async {
    if (_cached != null) return _cached!;
    final candidates = <String>[];
    if (Platform.isWindows) {
      final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      candidates.addAll([
        r'$windir\Fonts\msyh.ttc'.replaceFirst(r'$windir', windir),
        r'$windir\Fonts\msyhl.ttc'.replaceFirst(r'$windir', windir),
        r'$windir\Fonts\simhei.ttf'.replaceFirst(r'$windir', windir),
        r'$windir\Fonts\simsun.ttc'.replaceFirst(r'$windir', windir),
      ]);
    } else if (Platform.isAndroid) {
      candidates.addAll(const [
        '/system/fonts/NotoSansCJK-Regular.ttc',
        '/system/fonts/NotoSansCJKsc-Regular.ttc',
        '/system/fonts/NotoSansSC-Regular.ttf',
        '/system/fonts/DroidSansFallbackFull.ttf',
        '/system/fonts/DroidSansFallback.ttf',
      ]);
    } else if (Platform.isLinux) {
      candidates.addAll(const [
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
      ]);
    } else if (Platform.isMacOS) {
      candidates.addAll(const [
        '/System/Library/Fonts/PingFang.ttc',
        '/System/Library/Fonts/STHeiti Light.ttc',
      ]);
    }

    for (final path in candidates) {
      try {
        final f = File(path);
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final ttf = path.toLowerCase().endsWith('.ttc')
            ? _extractFirstFontFromTtc(bytes)
            : bytes;
        if (ttf == null) continue;
        final font = pw.Font.ttf(ByteData.sublistView(ttf));
        _cached = AppFont._(font, path);
        return _cached!;
      } catch (_) {
        continue;
      }
    }
    _cached = AppFont._(null, '内置 Helvetica');
    return _cached!;
  }
}

/// 从 TTC (TrueType Collection) 中提取第一个字体为独立 TTF 字节。
///
/// TTC 头部结构: tag(4) version(4) numFonts(4) offsets[numFonts](4 each)。
/// 从第一个字体偏移处切片到文件尾，即得到该字体的完整 sfnt 数据
/// （尾部多余字节会被解析器忽略）。
Uint8List? _extractFirstFontFromTtc(Uint8List bytes) {
  try {
    final bd = ByteData.sublistView(bytes);
    final tag = String.fromCharCodes(bytes.sublist(0, 4));
    if (tag != 'ttcf') return null;
    final numFonts = bd.getUint32(8);
    if (numFonts == 0) return null;
    final firstOffset = bd.getUint32(12);
    if (firstOffset <= 0 || firstOffset >= bytes.length) return null;
    return Uint8List.sublistView(bytes, firstOffset);
  } catch (_) {
    return null;
  }
}
