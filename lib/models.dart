import 'package:flutter/material.dart';

/// 功能类型定义与全局模型
enum FeatureType {
  wordToPdf('Word 转 PDF', '将 Word 文档转换为 PDF，Windows 端优先调用本机 WPS/Office 高保真转换', Icons.description),
  imageToPdf('图片 转 PDF', '将多张图片合并为一个 PDF 文件，支持自动页面与 A4 排版', Icons.image),
  imageCompress('图片 压缩', '批量压缩 JPG/PNG/WebP/BMP 图片，可控制清晰度', Icons.compress),
  pdfCompress('PDF 压缩', '压缩 PDF 文件体积，可选压缩强度', Icons.picture_as_pdf),
  wordCompress('Word 压缩', '压缩 docx 内嵌图片与文档体积，不破坏可编辑性', Icons.folder_zip);

  const FeatureType(this.title, this.desc, this.icon);
  final String title;
  final String desc;
  final IconData icon;
}

class CompressResult {
  const CompressResult({
    required this.outputPath,
    required this.beforeSize,
    required this.afterSize,
    this.warning,
  });

  final String outputPath;
  final int beforeSize;
  final int afterSize;
  final String? warning;

  double get savedPercent =>
      beforeSize <= 0 ? 0 : (1 - afterSize / beforeSize) * 100;
}

class ConvertResult {
  const ConvertResult({required this.outputPath, this.warning});
  final String outputPath;
  final String? warning;
}
