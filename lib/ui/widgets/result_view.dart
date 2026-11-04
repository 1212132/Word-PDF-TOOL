import 'package:flutter/material.dart';

import '../../../utils/file_utils.dart';
import '../../../utils/format.dart';

/// 结果卡片：输出路径 + 体积对比 + 打开/分享
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.title,
    required this.path,
    required this.badge,
    this.beforeSize,
    required this.afterSize,
    this.warning,
  });

  final String title;
  final String path;
  final String badge;
  final int? beforeSize;
  final int afterSize;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final saved = beforeSize != null && beforeSize! > 0
        ? (1 - afterSize / beforeSize!) * 100
        : null;
    final reduced = saved != null && saved > 0;

    return Card(
      color: const Color(0xFFEAF7EE),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1E8E3E)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E8E3E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E8E3E),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(path, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (beforeSize != null)
              Row(
                children: [
                  Text('${formatBytes(beforeSize!)} → ${formatBytes(afterSize)}',
                      style: const TextStyle(fontSize: 14)),
                  if (saved != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: reduced
                            ? const Color(0xFF1E8E3E).withValues(alpha: 0.12)
                            : const Color(0xFFE37400).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reduced
                            ? '体积减少 ${saved.toStringAsFixed(1)}%'
                            : '变化 ${saved.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 12,
                            color: reduced
                                ? const Color(0xFF1E8E3E)
                                : const Color(0xFFB06000),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              )
            else
              Text('输出大小: ${formatBytes(afterSize)}',
                  style: const TextStyle(fontSize: 14)),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFFB06000)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(warning!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFB06000)))),
              ]),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => openResult(path),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('打开'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => shareOrReveal(path),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('分享 / 所在文件夹'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
