// 为 docs/ 下所有 Markdown 文档追加「GitHub 原文链接 + 报告错误」页脚。
//
// 幂等：重复执行只会覆盖已存在的页脚，不会重复追加。
// 跨平台：Windows / macOS 均可运行（已统一路径分隔符，无需分支判断）。
// 用法（仓库根目录）：dart tool/add_source_footer.dart
import 'dart:io';

const String repoBlobBase =
    'https://github.com/Dboy233/flutter_zero_doc/blob/main';
const String repoIssuesNew =
    'https://github.com/Dboy233/flutter_zero_doc/issues/new';

// 页脚起始标记：用 HTML 注释锚定，便于幂等替换且不会渲染出来。
const String marker = '<!-- source-footer -->';

const Map<String, String> labels = {
  'zh': '本页原文：',
  'en': 'Source of this page: ',
};

// 报告链接文案（按语言）。
const Map<String, String> reportLabels = {
  'zh': '报告本页错误',
  'en': 'Report an error on this page',
};

// 隐藏式 issue 模板：文件不带 frontmatter，不会出现在 Issues 选择页，
// 仅通过文档页脚链接的 ?template= 参数打开。
const Map<String, String> reportTemplateByLang = {
  'zh': 'doc_bug_zh.md',
  'en': 'doc_bug_en.md',
};

/// 把任意系统的路径分隔符统一成 '/'，保证 URL 与语言判定跨平台一致。
String toPosix(String path) => path.replaceAll('\\', '/');

/// 根据文档相对 docs/ 的路径生成页脚文本。
String buildFooter(String posixPath) {
  final String lang = posixPath.split('/').first;
  final String srcLabel = labels[lang] ?? labels['en']!;
  final String srcUrl = '$repoBlobBase/docs/$posixPath';

  // 报告链接：按语言选择隐藏模板，标题带语言关键字便于分类。
  // 注意：template 与 body 同时存在时 GitHub 以 template 为准，
  // 故此处只传 template + title，正文结构由模板文件提供。
  final String reportLabel = reportLabels[lang] ?? reportLabels['en']!;
  final String reportTemplate =
      reportTemplateByLang[lang] ?? reportTemplateByLang['en']!;
  final String reportTitle = lang == 'zh'
      ? '【文档错误】docs/$posixPath'
      : '[Docs error] docs/$posixPath';
  final String reportUrl =
      '$repoIssuesNew?template=$reportTemplate'
      '&title=${Uri.encodeComponent(reportTitle)}';

  return '$marker\n\n---\n\n'
      '*${srcLabel}[docs/$posixPath]($srcUrl)*\n\n'
      '*[$reportLabel]($reportUrl)*\n';
}

/// 写入页脚，返回内容是否发生变化。
bool applyFooter(File file, String docsRoot) {
  final String rel = toPosix(file.path).replaceFirst('$docsRoot/', '');
  final String original = file.readAsStringSync();

  // 去掉旧页脚（若有），再统一追加新的。
  final String body = original
      .split(marker)
      .first
      .replaceAll(RegExp(r'\n+$'), '');
  final String updated = '$body\n\n${buildFooter(rel)}';

  if (updated == original) return false;
  file.writeAsStringSync(updated);
  return true;
}

void main() {
  // 脚本位于 <repo>/tool/add_source_footer.dart，docs 目录在其父级的父级。
  final String script = toPosix(File(Platform.script.toFilePath()).path);
  final String docsRoot = toPosix(File(script).parent.parent.path) + '/docs';

  final List<File> mdFiles =
      Directory(docsRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.md'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (mdFiles.isEmpty) {
    stderr.writeln('未找到任何 Markdown 文件');
    exit(1);
  }

  int changed = 0;
  for (final File file in mdFiles) {
    final String rel = toPosix(file.path).replaceFirst('$docsRoot/', '');
    if (applyFooter(file, docsRoot)) {
      changed++;
      print('  updated  $rel');
    } else {
      print('  skipped  $rel');
    }
  }
  print('\n共 ${mdFiles.length} 个文件，更新 $changed 个。');
}
