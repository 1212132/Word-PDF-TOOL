import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/word_to_pdf_service.dart';
import '../utils/file_utils.dart';
import '../utils/format.dart';
import 'widgets/result_view.dart';

class WordToPdfPage extends StatefulWidget {
  const WordToPdfPage({super.key});

  @override
  State<WordToPdfPage> createState() => _WordToPdfPageState();
}

class _WordToPdfPageState extends State<WordToPdfPage> {
  String? _input;
  bool _running = false;
  String _stage = '';
  ConvertResult? _result;
  String? _error;

  Future<void> _pick() async {
    final path = await pickSingleFile(['docx', 'doc']);
    if (path != null) {
      setState(() {
        _input = path;
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _run() async {
    if (_input == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _stage = '准备中…';
    });
    try {
      final outDir = _outputDirOf(_input!);
      final out = await WordToPdfService.convert(
        _input!,
        outDir,
        onStage: (s) => setState(() => _stage = s),
      );
      setState(() {
        _result = ConvertResult(outputPath: out);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _running = false;
        _stage = '';
      });
    }
  }

  String _outputDirOf(String input) {
    final sep = Platform.isWindows ? '\\' : '/';
    final i = input.lastIndexOf(sep);
    return i < 0 ? '.' : input.substring(0, i);
  }

  @override
  Widget build(BuildContext context) {
    final inputSize = _input == null ? 0 : File(_input!).lengthSync();
    return Scaffold(
      appBar: AppBar(title: const Text('Word 转 PDF')),
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
                          const Icon(Icons.description, color: Color(0xFF2F6FED)),
                          const SizedBox(width: 8),
                          const Text('选择 Word 文档',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _running ? null : _pick,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('选择文件'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_input == null)
                        Text('支持 .docx / .doc（电脑端 .doc 依赖本机 WPS/Office）',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13))
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.article_outlined),
                          title: Text(_input!.split(RegExp(r'[\\/]')).last,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(formatBytes(inputSize)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _running
                                ? null
                                : () => setState(() => _input = null),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_input == null || _running) ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_running ? _stage : '开始转换'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Card(
                  color: const Color(0xFFFDECEC),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Color(0xFFD93025)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                ),
              if (_result != null)
                ResultView(
                  title: '转换完成',
                  path: _result!.outputPath,
                  beforeSize: inputSize,
                  afterSize: File(_result!.outputPath).lengthSync(),
                  badge: 'PDF',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
