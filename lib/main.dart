import 'dart:io';

import 'package:flutter/material.dart';

import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordPdfToolApp());
}

class WordPdfToolApp extends StatelessWidget {
  const WordPdfToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文档转换压缩工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FED)),
        // Windows 端显式使用雅黑，保证中文渲染间距正常
        fontFamily: Platform.isWindows ? 'Microsoft YaHei UI' : null,
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE5E9F2)),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}
