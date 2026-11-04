import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/image_to_pdf_service.dart';
import '../utils/file_utils.dart';
import 'widgets/result_view.dart';

class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  final List<String> _images = [];
  PageSizeMode _mode = PageSizeMode.a4;
  bool _running = false;
  int _done = 0;
  ConvertResult? _result;
  String? _error;

  Future<void> _pick() async {
    final paths = await pickMultiFiles(['jpg', 'jpeg', 'png', 'webp', 'bmp']);
    if (paths.isNotEmpty) {
      setState(() {
        _images.addAll(paths);
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _run() async {
    if (_images.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final first = _images.first;
      final sep = Platform.isWindows ? '\\' : '/';
      final outDir =
          first.substring(0, first.lastIndexOf(sep) < 0 ? 0 : first.lastIndexOf(sep));
      final out = await ImageToPdfService.convert(
        List<String>.from(_images),
        outDir,
        options: ImageToPdfOptions(pageSizeMode: _mode),
        onProgress: (d, t) => setState(() => _done = d),
      );
      setState(() => _result = ConvertResult(outputPath: out));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  void _move(int index, int delta) {
    final j = index + delta;
    if (j < 0 || j >= _images.length) return;
    setState(() {
      final t = _images[index];
      _images[index] = _images[j];
      _images[j] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片 转 PDF')),
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
                          const Icon(Icons.image, color: Color(0xFF2F6FED)),
                          const SizedBox(width: 8),
                          Text('已选 ${_images.length} 张图片',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _running ? null : _pick,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加图片'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_images.isEmpty)
                        Text('支持 JPG / PNG / WebP / BMP，可多选并调整顺序',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13))
                      else
                        ..._buildList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('页面设置',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      RadioListTile(
                        dense: true,
                        title: const Text('A4 页面（自动缩放适配）'),
                        value: PageSizeMode.a4,
                        groupValue: _mode,
                        onChanged: (v) => setState(() => _mode = v!),
                      ),
                      RadioListTile(
                        dense: true,
                        title: const Text('跟随图片尺寸（保持原始比例）'),
                        value: PageSizeMode.auto,
                        groupValue: _mode,
                        onChanged: (v) => setState(() => _mode = v!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_images.isEmpty || _running) ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_running
                    ? '正在转换 ($_done/${_images.length})…'
                    : '开始转换'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Card(
                  color: const Color(0xFFFDECEC),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              if (_result != null)
                ResultView(
                  title: '转换完成',
                  path: _result!.outputPath,
                  afterSize: File(_result!.outputPath).lengthSync(),
                  badge: 'PDF',
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    final w = <Widget>[];
    for (var i = 0; i < _images.length; i++) {
      final p = _images[i];
      w.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(p),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 44, height: 44, color: Colors.grey.shade200),
            ),
          ),
          title: Text(p.split(RegExp(r'[\\/]')).last,
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
          trailing: _running
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: i == 0 ? null : () => _move(i, -1)),
                    IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == _images.length - 1
                            ? null
                            : () => _move(i, 1)),
                    IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _images.removeAt(i))),
                  ],
                ),
        ),
      );
    }
    return w;
  }
}
