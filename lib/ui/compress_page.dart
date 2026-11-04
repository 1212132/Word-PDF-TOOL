import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/compress_services.dart';
import '../utils/file_utils.dart';
import '../utils/format.dart';
import 'widgets/result_view.dart';

class CompressPage extends StatefulWidget {
  const CompressPage({super.key, required this.feature});

  final FeatureType feature;

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  final List<String> _files = [];
  CompressLevel _level = CompressLevel.balanced;
  bool _running = false;
  int _done = 0;
  final List<CompressResult> _results = [];
  final List<String> _errors = [];

  List<String> get _extensions {
    switch (widget.feature) {
      case FeatureType.imageCompress:
        return ['jpg', 'jpeg', 'png', 'webp', 'bmp'];
      case FeatureType.pdfCompress:
        return ['pdf'];
      case FeatureType.wordCompress:
        return ['docx'];
      default:
        return ['*'];
    }
  }

  bool get _multi => widget.feature == FeatureType.imageCompress;

  Future<void> _pick() async {
    final paths = _multi ? await pickMultiFiles(_extensions) : [
      if (await pickSingleFile(_extensions) case final p?) p
    ];
    if (paths.isNotEmpty) {
      setState(() {
        _files.addAll(paths);
        _results.clear();
        _errors.clear();
      });
    }
  }

  Future<void> _run() async {
    if (_files.isEmpty || _running) return;
    setState(() {
      _running = true;
      _results.clear();
      _errors.clear();
    });
    final sep = Platform.isWindows ? '\\' : '/';
    try {
      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        final outDir =
            f.substring(0, f.lastIndexOf(sep) < 0 ? 0 : f.lastIndexOf(sep));
        try {
          final CompressResult r;
          switch (widget.feature) {
            case FeatureType.imageCompress:
              r = await ImageCompressService.compress(f, outDir, _level);
              break;
            case FeatureType.pdfCompress:
              r = await PdfCompressService.compress(f, outDir, _level);
              break;
            case FeatureType.wordCompress:
              r = await WordCompressService.compress(f, outDir, _level);
              break;
            default:
              throw Exception('未知功能');
          }
          setState(() {
            _results.add(r);
            _done = i + 1;
          });
        } catch (e) {
          setState(() {
            _errors.add('${_name(f)}: $e');
            _done = i + 1;
          });
        }
      }
    } finally {
      setState(() => _running = false);
    }
  }

  String _name(String p) => p.split(RegExp(r'[\\/]')).last;

  @override
  Widget build(BuildContext context) {
    final totalBefore =
        _results.fold<int>(0, (s, r) => s + r.beforeSize);
    final totalAfter = _results.fold<int>(0, (s, r) => s + r.afterSize);

    return Scaffold(
      appBar: AppBar(title: Text(widget.feature.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(widget.feature.icon, color: const Color(0xFF2F6FED)),
                          const SizedBox(width: 8),
                          Text('已选 ${_files.length} 个文件',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _running ? null : _pick,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('选择文件'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_files.isEmpty)
                        Text(
                          widget.feature == FeatureType.imageCompress
                              ? '支持 JPG / PNG / WebP / BMP，可批量'
                              : widget.feature == FeatureType.pdfCompress
                                  ? '选择一个 PDF 文件'
                                  : '选择一个 .docx 文件',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        )
                      else
                        ..._files.asMap().entries.map((e) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.insert_drive_file_outlined),
                              title: Text(_name(e.value),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5)),
                              subtitle: Text(formatBytes(File(e.value).lengthSync())),
                              trailing: _running
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () =>
                                          setState(() => _files.removeAt(e.key)),
                                    ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('压缩强度',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ...CompressLevel.values.map(
                        (l) => RadioListTile(
                          dense: true,
                          title: Text(l.label),
                          value: l,
                          groupValue: _level,
                          onChanged: (v) => setState(() => _level = v!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_files.isEmpty || _running) ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.compress),
                label: Text(_running
                    ? '正在压缩 ($_done/${_files.length})…'
                    : '开始压缩'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 20),
              if (_errors.isNotEmpty)
                Card(
                  color: const Color(0xFFFDECEC),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _errors
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(e,
                                    style: const TextStyle(
                                        fontSize: 12.5, color: Color(0xFFB3261E))),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              if (_results.isNotEmpty) ...[
                if (_results.length > 1)
                  Card(
                    color: const Color(0xFFEAF1FE),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.assessment_outlined,
                              color: Color(0xFF2F6FED)),
                          const SizedBox(width: 10),
                          Text(
                            '合计: ${formatBytes(totalBefore)} → ${formatBytes(totalAfter)}，'
                            '节省 ${(1 - totalAfter / (totalBefore == 0 ? 1 : totalBefore)) * 100}%',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ..._results.map((r) => ResultView(
                      title: '压缩完成',
                      path: r.outputPath,
                      beforeSize: r.beforeSize,
                      afterSize: r.afterSize,
                      badge: widget.feature == FeatureType.wordCompress
                          ? 'DOCX'
                          : widget.feature == FeatureType.pdfCompress
                              ? 'PDF'
                              : 'IMG',
                      warning: r.warning,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
