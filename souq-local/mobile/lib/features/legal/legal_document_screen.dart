import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';
import 'legal_documents.dart';

class LegalDocumentScreen extends ConsumerStatefulWidget {
  const LegalDocumentScreen({super.key, required this.docSlug});

  final String docSlug;

  @override
  ConsumerState<LegalDocumentScreen> createState() =>
      _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  late Future<_LegalDocumentContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LegalDocumentContent> _load() async {
    final lang = Localizations.localeOf(context).languageCode;
    final url = AppConfig.legalDocumentUrl(widget.docSlug, lang);
    final response = await http
        .get(Uri.parse(url))
        .timeout(AppConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to load document',
      );
    }
    final html = utf8.decode(response.bodyBytes);
    return _LegalDocumentContent.parse(html);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doc = LegalDocumentId.fromSlug(widget.docSlug);
    final title = doc?.titleBuilder(l10n) ?? l10n.privacyAndLegal;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: title),
      body: FutureBuilder<_LegalDocumentContent>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            );
          }
          if (snapshot.hasError) {
            return AsyncErrorView.fromError(
              snapshot.error!,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final content = snapshot.data!;
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.md,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  content.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (content.meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    content.meta,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ...content.blocks.map((block) => _DocumentBlock(block: block)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentBlock extends StatelessWidget {
  const _DocumentBlock({required this.block});

  final _Block block;

  @override
  Widget build(BuildContext context) {
    return switch (block.kind) {
      _BlockKind.heading => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Text(
            block.text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      _BlockKind.paragraph => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            block.text,
            style: TextStyle(
              color: context.colors.textPrimary,
              height: 1.55,
            ),
          ),
        ),
      _BlockKind.note => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            block.text,
            style: TextStyle(
              color: context.colors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      _BlockKind.bullet => Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: context.colors.primary)),
              Expanded(
                child: Text(
                  block.text,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      _BlockKind.tableRow => _LegalTableRow(cells: block.cells),
    };
  }
}

class _LegalTableRow extends StatelessWidget {
  const _LegalTableRow({required this.cells});

  final List<String> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 3,
              child: Text(
                cells[i],
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );

enum _BlockKind { heading, paragraph, note, bullet, tableRow }

class _Block {
  const _Block(this.kind, this.text, {this.cells = const []});

  final _BlockKind kind;
  final String text;
  final List<String> cells;
}

class _LegalDocumentContent {
  const _LegalDocumentContent({
    required this.title,
    required this.meta,
    required this.blocks,
  });

  final String title;
  final String meta;
  final List<_Block> blocks;

  static _LegalDocumentContent parse(String html) {
    final title = _firstMatch(html, RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true));
    final meta = _firstMatch(html, RegExp(r'<p class="meta"[^>]*>(.*?)</p>', dotAll: true));
    final main = _firstMatch(html, RegExp(r'<main>(.*?)</main>', dotAll: true)) ?? html;

    final blocks = <_Block>[];
    final tokenPattern = RegExp(
      r'<h2[^>]*>.*?</h2>|<div class="note"[^>]*>.*?</div>|<table>.*?</table>|<p[^>]*>.*?</p>|<li[^>]*>.*?</li>',
      dotAll: true,
    );

    for (final match in tokenPattern.allMatches(main)) {
      final chunk = match.group(0) ?? '';
      if (chunk.startsWith('<h2')) {
        blocks.add(_Block(_BlockKind.heading, _stripTags(chunk)));
      } else if (chunk.contains('class="note"')) {
        blocks.add(_Block(_BlockKind.note, _stripTags(chunk)));
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
            blocks.add(_Block(_BlockKind.tableRow, '', cells: cells));
          }
        }
      } else if (chunk.startsWith('<li')) {
        blocks.add(_Block(_BlockKind.bullet, _stripTags(chunk)));
      } else {
        final text = _stripTags(chunk);
        if (text.isNotEmpty) {
          blocks.add(_Block(_BlockKind.paragraph, text));
        }
      }
    }

    return _LegalDocumentContent(
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

void openLegalDocument(BuildContext context, LegalDocumentId doc) {
  context.push('/legal/${doc.slug}');
}
