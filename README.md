# Word图片转PDF（含压缩功能）

一套 Flutter 代码，同时构建 **Windows 桌面 EXE** 与 **Android 手机 APP**。

## 下载使用（绿色免安装）

直接下载仓库中的 **`word_pdf_tool_绿色免安装版.zip`**（约 15MB），解压到任意文件夹，双击 `word_pdf_tool.exe` 即可使用：
- 无需安装，不写注册表，删除文件夹即卸载
- 要求：Windows 10（1809+）/ Windows 11，64 位
- 所有转换压缩均在本地完成，不上传任何文件
- 手机 APP 源码也在本仓库，可用 Flutter 自行打包 APK

## 功能

| 功能 | 实现方式 | 平台支持 |
|---|---|---|
| Word 转 PDF | Windows 优先调用本机 WPS/Office（COM，高保真），失败自动回退内置 docx 解析引擎；手机端使用内置引擎 | Windows / Android |
| 图片 转 PDF | `pdf` 包纯 Dart 生成，支持多图合并、排序、A4 / 原尺寸页面 | 全平台 |
| 图片 压缩 | 缩放 + JPEG 质量重编码（PNG 含透明时保留 PNG） | 全平台 |
| PDF 压缩 | 页面栅格化后重建 PDF（pdfx 渲染 + pdf 重建） | Windows / Android |
| Word 压缩 | 重压缩 docx 内嵌图片 + zip 重新打包，不破坏可编辑性 | 全平台 |

内置 docx 引擎支持：段落、标题样式（Heading1-6/Title）、加粗/斜体/下划线、字号、字色、对齐、内嵌图片、表格、项目符号列表。艺术字/文本框/公式/SmartArt 等复杂元素会简化显示。

## 目录结构

```
lib/
├── main.dart                     # 应用入口
├── models.dart                   # 功能类型与结果模型
├── services/
│   ├── font_loader.dart          # CJK 字体加载（TTC 切片，不打包字体）
│   ├── image_to_pdf_service.dart # 图片 → PDF
│   ├── word_to_pdf_service.dart  # Word → PDF（内置引擎）
│   ├── native_office.dart        # Windows COM 调用 WPS/Office
│   └── compress_services.dart    # 图片/PDF/Word 三类压缩
├── ui/
│   ├── home_page.dart            # 功能入口
│   ├── image_to_pdf_page.dart
│   ├── word_to_pdf_page.dart
│   ├── compress_page.dart        # 通用压缩页
│   └── widgets/result_view.dart  # 结果卡片（体积对比/打开/分享）
└── utils/
    ├── file_utils.dart           # 文件选择/打开/分享
    └── format.dart               # 字节格式化
```

## 部署条件（其他电脑使用）

**Windows 版为绿色免安装**：`word_pdf_tool_绿色免安装版.zip`（15MB）解压到任意目录即可运行，无需安装任何依赖。

- ✅ 内置 VC++ 运行库 DLL（msvcp140/vcruntime140，随包分发）
- ✅ 内置 PDFium 引擎（PDF 压缩所需）
- ✅ 主程序已静态链接 CRT
- 要求：Windows 10（1809+）/ Windows 11，64 位
- Word 转 PDF 的高保真模式依赖目标电脑装有 WPS 或 Office；未安装时自动回退内置引擎（支持常规排版），其余功能不受影响

## 构建

环境要求：Flutter SDK（D:\flutter 已装）+ Android SDK（打 APK 时需要）+ VS 2022 Build Tools（C++ 工作负载，打 EXE 必需）。

```bash
# Windows EXE
flutter build windows --release
# 产物: build/windows/x64/runner/Release/word_pdf_tool.exe（整个 Release 目录需一起分发）

# Android APK
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

## 技术要点

- **中文字体**：运行时从系统加载（Windows 微软雅黑/黑体，Android NotoSansCJK/DroidSansFallback），TTC 集合字体通过 sfnt 切片提取为 TTF 后交给 pdf 包做子集化嵌入
- **本地优先**：所有转换与压缩均在本地完成，无任何网络上传
- **压缩强度**：三档（高压缩/均衡/轻度），PDF 压缩为栅格化重建，纯文字 PDF 可能不减反增（界面会提示）
