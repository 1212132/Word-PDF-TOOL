import 'dart:convert';
import 'dart:io';

/// 通过本机 Office / WPS 的 COM 接口做高保真 Word -> PDF 转换。
/// 仅 Windows 可用；依赖系统已安装 Word 或 WPS。
/// 任何失败（未安装、转换报错）都返回 null，由调用方回退到内置引擎。
class NativeOfficeConverter {
  static const _maxWait = Duration(minutes: 5);

  static bool get isSupported => Platform.isWindows;

  static Future<String?> convert(String inputPath, String outputPath) async {
    if (!isSupported) return null;
    if (!File(inputPath).existsSync()) return null;

    // PS 单引号字符串中单引号需双写转义
    final inp = inputPath.replaceAll("'", "''");
    final out = outputPath.replaceAll("'", "''");

    // 优先 WPS（国产环境更常见），失败回退 Word。
    // 脚本中 $xxx 为 PowerShell 变量；Dart 字符串里用 \$ 转义。
    final script = '''
\$ErrorActionPreference = 'Stop'
\$inp = '$inp'
\$out = '$out'
\$app = \$null
try {
  \$app = New-Object -ComObject KWPS.Application
} catch {
  try {
    \$app = New-Object -ComObject Word.Application
  } catch {
    Write-Output 'NO_COM'
    exit 1
  }
}
try {
  \$app.Visible = \$false
  \$doc = \$app.Documents.Open(\$inp, \$false, \$true)
  \$doc.ExportAsFixedFormat(\$out, 17)
  \$doc.Close(\$false)
} finally {
  try { \$app.Quit() } catch {}
}
if (Test-Path \$out) { Write-Output 'OK' } else { exit 1 }
''';

    try {
      final r = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(_maxWait,
          onTimeout: () => ProcessResult(-1, -1, '', 'timeout'));
      final ok = r.exitCode == 0 &&
          (r.stdout as String).trim().contains('OK') &&
          File(outputPath).existsSync();
      return ok ? outputPath : null;
    } catch (_) {
      return null;
    }
  }
}
