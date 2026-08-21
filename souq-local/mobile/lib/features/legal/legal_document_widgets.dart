import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import 'legal_document_content.dart';

class LegalDocumentBody extends StatelessWidget {
  const LegalDocumentBody({super.key, required this.content});

  final LegalDocumentContent content;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          const SizedBox(height: AppSpacing.md),
          ...content.blocks.map((block) => LegalDocumentBlock(block: block)),
        ],
      ),
    );
  }
}

class LegalDocumentBlock extends StatelessWidget {
  const LegalDocumentBlock({super.key, required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block.kind) {
      LegalBlockKind.heading => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Text(
            block.text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      LegalBlockKind.paragraph => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            block.text,
            style: TextStyle(
              color: context.colors.textPrimary,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ),
      LegalBlockKind.note => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
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
              fontSize: 13,
            ),
          ),
        ),
      LegalBlockKind.bullet => Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 4),
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
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      LegalBlockKind.tableRow => _LegalTableRow(cells: block.cells),
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
  }
}
