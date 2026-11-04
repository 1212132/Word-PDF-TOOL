import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// 打开文件（系统默认方式）
Future<void> openResult(String path) async {
  await OpenFilex.open(path);
}

/// 分享文件（移动端分享面板；桌面端打开所在文件夹并选中）
Future<void> shareOrReveal(String path) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  } else if (Platform.isWindows) {
    final dir = File(path).parent.path;
    await Process.run('explorer.exe', ['/select,', path], workingDirectory: dir);
  } else {
    await OpenFilex.open(File(path).parent.path);
  }
}

/// 打开所在文件夹（桌面端）
Future<void> revealInFolder(String path) async {
  if (Platform.isWindows) {
    final dir = File(path).parent.path;
    await Process.run('explorer.exe', ['/select,', path], workingDirectory: dir);
  } else {
    await OpenFilex.open(File(path).parent.path);
  }
}

const kIsDesktop = null; // 已弃用

/// 选择单个文件
Future<String?> pickSingleFile(List<String> extensions) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: false,
  );
  return r?.files.single.path;
}

/// 选择多个文件
Future<List<String>> pickMultiFiles(List<String> extensions) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: false,
  );
  return r?.files.map((f) => f.path!).whereType<String>().toList() ??
      const <String>[];
}
