import 'package:flutter/material.dart';

import '../models.dart';
import 'compress_page.dart';
import 'image_to_pdf_page.dart';
import 'word_to_pdf_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final features = FeatureType.values;
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档转换压缩工具',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: const Color(0xFFF5F7FB),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '选择功能',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 108,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: features.length,
                itemBuilder: (context, i) {
                  final f = features[i];
                  return _FeatureCard(
                    feature: f,
                    onTap: () => _open(context, f),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                '提示：Word 转 PDF 在电脑端会优先使用已安装的 WPS 或 Office 获得最佳还原度；'
                '所有功能均在本地完成，文件不会上传到任何服务器。',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, FeatureType f) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      switch (f) {
        case FeatureType.wordToPdf:
          return const WordToPdfPage();
        case FeatureType.imageToPdf:
          return const ImageToPdfPage();
        default:
          return CompressPage(feature: f);
      }
    }));
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.onTap});
  final FeatureType feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6FED).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(feature.icon, color: const Color(0xFF2F6FED), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(feature.title,
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(feature.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
