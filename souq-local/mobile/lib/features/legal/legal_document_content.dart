import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';

enum LegalBlockKind { heading, paragraph, note, bullet, tableRow }

class LegalBlock {
  const LegalBlock(this.kind, this.text, {this.cells = const []});

  final LegalBlockKind kind;
  final String text;
  final List<String> cells;
}

class LegalDocumentContent {
  const LegalDocumentContent({
    required this.title,
    required this.meta,
    required this.blocks,
  });

  final String title;
  final String meta;
  final List<LegalBlock> blocks;

  static Future<LegalDocumentContent> fetch(String docSlug) async {
    final url = AppConfig.legalDocumentUrl(docSlug);
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load document',
        statusCode: response.statusCode,
      );
    }
    final html = utf8.decode(response.bodyBytes);
    return parse(html);
  }

  static LegalDocumentContent parse(String html) {
    final title = _firstMatch(html, RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true));
    final meta = _firstMatch(html, RegExp(r'<p class="meta"[^>]*>(.*?)</p>', dotAll: true));
    final main = _firstMatch(html, RegExp(r'<main>(.*?)</main>', dotAll: true)) ?? html;

    final blocks = <LegalBlock>[];
    final tokenPattern = RegExp(
      r'<h2[^>]*>.*?</h2>|<div class="note"[^>]*>.*?</div>|<table>.*?</table>|<p[^>]*>.*?</p>|<li[^>]*>.*?</li>',
      dotAll: true,
    );

    for (final match in tokenPattern.allMatches(main)) {
      final chunk = match.group(0) ?? '';
      if (chunk.startsWith('<h2')) {
        blocks.add(LegalBlock(LegalBlockKind.heading, _stripTags(chunk)));
      } else if (chunk.contains('class="note"')) {
        blocks.add(LegalBlock(LegalBlockKind.note, _stripTags(chunk)));
      } else if (chunk.startsWith('<table')) {
        final rowPattern = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
        for (final rowMatch in rowPattern.allMatches(chunk)) {
          final rowHtml = rowMatch.group(1) ?? '';
          final cellPattern = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true);
          final cells = cellPattern
              .allMatches(rowHtml)
              .map((m) => _decode(_stripTags(m.group(1) ?? '')))
              .where((c) => c.isNotEmpty)
              .toList();
          if (cells.isNotEmpty) {
            blocks.add(LegalBlock(LegalBlockKind.tableRow, '', cells: cells));
          }
        }
      } else if (chunk.startsWith('<li')) {
        blocks.add(LegalBlock(LegalBlockKind.bullet, _stripTags(chunk)));
      } else {
        final text = _stripTags(chunk);
        if (text.isNotEmpty) {
          blocks.add(LegalBlock(LegalBlockKind.paragraph, text));
        }
      }
    }

    return LegalDocumentContent(
      title: _decode(title.isEmpty ? 'Dribex' : title),
      meta: _decode(meta),
      blocks: blocks,
    );
  }

  static String _firstMatch(String input, RegExp pattern) {
    return pattern.firstMatch(input)?.group(1)?.trim() ?? '';
  }

  static String _stripTags(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _decode(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
