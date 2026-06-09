import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/section_header.dart";
import "../../core/auth_store.dart";
import "../catalog/toy_detail_screen.dart";
import "loan_due_date_header.dart";
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
            "Renewed ${updated.toyName ?? updated.toyId} until ${formatDisplayDate(updated.dueDate)}",
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

  void _openToy(String toyId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToyDetailScreen(toyId: toyId),
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

class _MyLoansView extends StatelessWidget {
  const _MyLoansView({
    required this.onRenew,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(LoanItem item) onRenew;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.myLoansLoading && c.myLoans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.myLoansError != null && c.myLoans.isEmpty) {
          return _ErrorState(
            message: c.myLoansError!,
            loading: c.myLoansLoading,
            onRetry: onRefresh,
          );
        }
        if (c.myLoans.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
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

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              for (var g = 0; g < sections.activeByDueDate.length; g++) ...[
                if (g > 0) const SizedBox(height: 20),
                LoanDueDateHeader(
                  dueDate: sections.activeByDueDate[g].dueDate,
                  isOverdue: sections.activeByDueDate[g].isOverdue,
                ),
                for (var i = 0;
                    i < sections.activeByDueDate[g].loans.length;
                    i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  LoanListTile(
                    item: sections.activeByDueDate[g].loans[i],
                    loading: c.myLoansLoading,
                    onOpen: () =>
                        onOpenToy(sections.activeByDueDate[g].loans[i].toyId),
                    onRenew: sections.activeByDueDate[g].loans[i].canRenew
                        ? () => onRenew(sections.activeByDueDate[g].loans[i])
                        : null,
                  ),
                ],
              ],
              if (sections.activeByDueDate.isNotEmpty &&
                  sections.returned.isNotEmpty)
                const SizedBox(height: 20),
              if (sections.returned.isNotEmpty) ...[
                const SectionHeader("Returned"),
                for (var i = 0; i < sections.returned.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  LoanListTile(
                    item: sections.returned[i],
                    loading: c.myLoansLoading,
                    onOpen: () => onOpenToy(sections.returned[i].toyId),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
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
