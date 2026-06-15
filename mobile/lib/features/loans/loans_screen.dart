import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/section_header.dart";
import "../../core/auth_store.dart";
import "../catalog/toy_detail_screen.dart";
import "loan_due_date_section.dart";
import "loan_list_tile.dart";
import "loan_models.dart";
import "loans_controller.dart";

/// Member and volunteer personal loans list.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LoansController>().loadMyLoans();
    });
  }

  Future<void> _renew(LoanItem item) async {
    final controller = context.read<LoansController>();
    try {
      final updated = await controller.renewLoan(item.loanId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Renewed ${updated.toyName ?? updated.toyId} until ${updated.returnDateLabel}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  void _openToy(LoanItem loan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToyDetailScreen(
          toyId: loan.toyId,
          initialToy: previewToyItem(
            toyId: loan.toyId,
            name: loan.toyName,
            photoFile: loan.photoFile,
            availability: "on_loan",
            totalPieces: loan.toyTotalPieces,
            missingPieces: loan.toyMissingPieces,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    if (!auth.isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Sign in to view your loans.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!auth.isMember && !auth.isVolunteer && !auth.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Complete membership setup to borrow toys from the library.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _MyLoansView(
      onRenew: _renew,
      onOpenToy: _openToy,
      onRefresh: () => context.read<LoansController>().loadMyLoans(),
    );
  }
}

class _MyLoansView extends StatefulWidget {
  const _MyLoansView({
    required this.onRenew,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(LoanItem item) onRenew;
  final ValueChanged<LoanItem> onOpenToy;
  final Future<void> Function() onRefresh;

  @override
  State<_MyLoansView> createState() => _MyLoansViewState();
}

class _MyLoansViewState extends State<_MyLoansView> {
  bool _returnedExpanded = false;

  Widget _loanTile(LoansController c, LoanItem loan, {bool inGroup = false}) {
    return LoanListTile(
      key: ValueKey(loan.loanId),
      item: loan,
      loading: c.myLoansLoading,
      inGroup: inGroup,
      onOpen: () => widget.onOpenToy(loan),
      onRenew: loan.canRenew ? () => widget.onRenew(loan) : null,
    );
  }

  List<_LoansRow> _loansListRows(LoanSections sections) {
    final rows = <_LoansRow>[];
    if (sections.activeByDueDate.isNotEmpty) {
      rows.add(const _LoansRow(_LoansRowType.activeHeader));
      for (var g = 0; g < sections.activeByDueDate.length; g++) {
        if (g > 0) {
          rows.add(const _LoansRow(_LoansRowType.groupGap));
        }
        rows.add(_LoansRow(_LoansRowType.dueGroup, groupIndex: g));
      }
    }
    if (sections.activeByDueDate.isNotEmpty && sections.returned.isNotEmpty) {
      rows.add(const _LoansRow(_LoansRowType.sectionGap));
    }
    if (sections.returned.isNotEmpty) {
      rows.add(const _LoansRow(_LoansRowType.returnedHeader));
      if (_returnedExpanded) {
        for (var i = 0; i < sections.returned.length; i++) {
          if (i > 0) {
            rows.add(const _LoansRow(_LoansRowType.returnedGap));
          }
          rows.add(_LoansRow(_LoansRowType.returnedLoan, loanIndex: i));
        }
      }
    }
    return rows;
  }

  Widget _buildLoansRow(
    LoansController controller,
    LoanSections sections,
    _LoansRow row,
  ) {
    switch (row.type) {
      case _LoansRowType.activeHeader:
        return const SectionHeader("Active");
      case _LoansRowType.groupGap:
        return const SizedBox(height: 12);
      case _LoansRowType.dueGroup:
        final group = sections.activeByDueDate[row.groupIndex!];
        return LoanDueDateSection(
          group: group,
          children: [
            for (final loan in group.loans)
              _loanTile(controller, loan, inGroup: true),
          ],
        );
      case _LoansRowType.sectionGap:
        return const SizedBox(height: 20);
      case _LoansRowType.returnedHeader:
        return CollapsibleSection(
          title: "Returned (${sections.returned.length})",
          expanded: _returnedExpanded,
          onToggle: () =>
              setState(() => _returnedExpanded = !_returnedExpanded),
          children: const [],
        );
      case _LoansRowType.returnedGap:
        return const SizedBox(height: 8);
      case _LoansRowType.returnedLoan:
        return _loanTile(controller, sections.returned[row.loanIndex!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.myLoansLoading && c.myLoans.isEmpty) {
          return const Center(child: ToyLibraryLoadingIndicator());
        }
        if (c.myLoansError != null && c.myLoans.isEmpty) {
          return _ErrorState(
            message: c.myLoansError!,
            loading: c.myLoansLoading,
            onRetry: widget.onRefresh,
          );
        }
        if (c.myLoans.isEmpty) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    "No loans yet.\nPick up a booking or borrow a toy at the desk.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final sections = groupLoansBySection(c.myLoans);
        final rows = _loansListRows(sections);

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              return _buildLoansRow(c, sections, rows[index]);
            },
          ),
        );
      },
    );
  }
}

enum _LoansRowType {
  activeHeader,
  groupGap,
  dueGroup,
  sectionGap,
  returnedHeader,
  returnedGap,
  returnedLoan,
}

class _LoansRow {
  const _LoansRow(
    this.type, {
    this.groupIndex,
    this.loanIndex,
  });

  final _LoansRowType type;
  final int? groupIndex;
  final int? loanIndex;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.loading,
    required this.onRetry,
  });

  final String message;
  final bool loading;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
