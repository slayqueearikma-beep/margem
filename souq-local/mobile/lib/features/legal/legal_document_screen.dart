import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';
import 'legal_document_content.dart';
import 'legal_document_widgets.dart';
import 'legal_documents.dart';

class LegalDocumentScreen extends ConsumerStatefulWidget {
  const LegalDocumentScreen({super.key, required this.docSlug});

  final String docSlug;

  @override
  ConsumerState<LegalDocumentScreen> createState() =>
      _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  Future<LegalDocumentContent>? _future;

  @override
  void initState() {
    super.initState();
    _future = LegalDocumentContent.fetch(widget.docSlug);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doc = LegalDocumentId.fromSlug(widget.docSlug);
    final title = doc?.titleBuilder(l10n) ?? l10n.privacyAndLegal;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: title),
      body: FutureBuilder<LegalDocumentContent>(
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
              onRetry: () {
                setState(() {
                  _future = LegalDocumentContent.fetch(widget.docSlug);
                });
              },
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
                LegalDocumentBody(content: content),
              ],
            ),
          );
        },
      ),
    );
  }
}

void openLegalDocument(BuildContext context, LegalDocumentId doc) {
  context.push('/legal/${doc.slug}');
}
