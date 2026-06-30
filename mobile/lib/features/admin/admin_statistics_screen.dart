import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/section_header.dart";
import "../duty/duty_session_models.dart";
import "admin_controller.dart";
import "admin_stats_pending_members_screen.dart";
import "admin_statistics_models.dart";

/// Admin statistics: period filters, overview cards, charts, toy popularity.
class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  final TextEditingController _sessionDateInput = TextEditingController();
  final FocusNode _sessionDateFocus = FocusNode();

  String _period = "month";
  DateTime? _sessionDate;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _groupBy = "category";
  String? _sessionDateError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _sessionDateFocus.dispose();
    _sessionDateInput.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_period == "session" && _sessionDate == null) return;

    final admin = context.read<AdminController>();
    await Future.wait([
      admin.loadStatsOverview(
        period: _period,
        sessionDate: _sessionDate,
        year: _year,
        month: _month,
      ),
      admin.loadStatsBreakdown(
        period: _period,
        sessionDate: _sessionDate,
        year: _year,
        month: _month,
        groupBy: _groupBy,
      ),
      admin.loadStatsCatalog(),
      admin.loadStatsHeardAbout(
        period: _period,
        sessionDate: _sessionDate,
        year: _year,
        month: _month,
      ),
      admin.loadToyPopularity(
        period: _period,
        sessionDate: _sessionDate,
        year: _year,
        month: _month,
      ),
    ]);
  }

  void _syncSessionInput(DateTime? date) {
    _sessionDateInput.text =
        date == null ? "" : formatSessionInputDate(date);
  }

  Future<void> _applySessionDate(DateTime date) async {
    if (!LibrarySessionTimes.isSessionDay(date)) {
      setState(() {
        _sessionDateError = "Library sessions are Wednesday or Saturday.";
      });
      return;
    }
    setState(() {
      _sessionDate = date;
      _sessionDateError = null;
      _period = "session";
      _syncSessionInput(date);
    });
    _sessionDateFocus.unfocus();
    await _reload();
  }

  Future<void> _applyTypedSessionDate() async {
    final parsed = parseSessionDateInput(_sessionDateInput.text);
    if (parsed == null) {
      setState(() {
        _sessionDateError = "Enter the date as dd/mm/yyyy.";
      });
      return;
    }
    await _applySessionDate(parsed);
  }

  Future<void> _openSessionCalendar() async {
    final picked = await showDatePicker(
      context: context,
      helpText: "Library session (Wed/Sat)",
      initialDate: _sessionDate ?? LibrarySessionTimes.nextSessionDay(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: LibrarySessionTimes.isSessionDay,
    );
    if (!mounted || picked == null) return;
    await _applySessionDate(picked);
  }

  String _localPeriodLabel() {
    switch (_period) {
      case "session":
        return _sessionDate == null
            ? "Pick a session"
            : formatSessionDate(_sessionDate!);
      case "month":
        return "${_monthNames[_month - 1]} $_year";
      case "year":
        return "$_year";
      case "all":
        return "All time";
      default:
        return "";
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(
      context,
      initialYear: _year,
      initialMonth: _month,
      monthNames: _monthNames,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _year = picked.year;
      _month = picked.month;
      _period = "month";
      _sessionDate = null;
      _sessionDateError = null;
      _syncSessionInput(null);
    });
    await _reload();
  }

  Future<void> _pickYear() async {
    final picked = await showYearPicker(
      context,
      initialYear: _year,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _year = picked;
      _period = "year";
      _sessionDate = null;
      _sessionDateError = null;
      _syncSessionInput(null);
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final overview = admin.statsOverview;
    final breakdown = admin.statsBreakdown;
    final catalog = admin.statsCatalog;
    final heardAbout = admin.statsHeardAbout;
    final popularity = admin.toyPopularity;
    final loading = admin.statsLoading;

    final periodLabel = _localPeriodLabel();

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _StatsFilterPanel(
              period: _period,
              periodLabel: periodLabel.isNotEmpty
                  ? periodLabel
                  : (overview?.periodLabel ?? "Loading…"),
              sessionDateInput: _sessionDateInput,
              sessionDateFocus: _sessionDateFocus,
              sessionDateError: _sessionDateError,
              year: _year,
              month: _month,
              onPeriodChanged: (value) async {
                setState(() {
                  _period = value;
                  if (value != "session") {
                    _sessionDate = null;
                    _sessionDateError = null;
                    _syncSessionInput(null);
                  }
                });
                if (value != "session" || _sessionDate != null) {
                  await _reload();
                }
              },
              onSessionTyped: _applyTypedSessionDate,
              onSessionCalendar: _openSessionCalendar,
              onMonthTap: _pickMonth,
              onYearTap: _pickYear,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                if (loading && overview == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: ToyLibraryLoadingIndicator(),
                    ),
                  )
                else if (admin.statsError != null && overview == null)
                  _ErrorCard(message: admin.statsError!)
                else if (overview != null) ...[
                  _OverviewGrid(
                    overview: overview,
                    period: _period,
                    sessionDate: _sessionDate,
                    year: _year,
                    month: _month,
                    periodLabel: periodLabel.isNotEmpty
                        ? periodLabel
                        : overview.periodLabel,
                  ),
                  const SizedBox(height: 8),
                  SectionHeader(
                    "Checkouts by ${statsGroupByTitle(_groupBy)}",
                  ),
                  _GroupByChips(
                    value: _groupBy,
                    onChanged: (value) async {
                      setState(() => _groupBy = value);
                      await context.read<AdminController>().loadStatsBreakdown(
                            period: _period,
                            sessionDate: _sessionDate,
                            year: _year,
                            month: _month,
                            groupBy: value,
                          );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (admin.statsBreakdownLoading ||
                      breakdown?.groupBy != _groupBy)
                    const SizedBox(
                      height: 120,
                      child: Center(
                        child: ToyLibraryLoadingIndicator.compact(),
                      ),
                    )
                  else if (breakdown != null && breakdown.data.isNotEmpty)
                    _BarChartCard(rows: breakdown.data)
                  else
                    const _EmptyChartCard(
                      message: "No checkouts in this period.",
                    ),
                  const SizedBox(height: 8),
                  const SectionHeader("How members found us"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      heardAbout == null
                          ? "Answers from registration in this period."
                          : "${heardAbout.totalResponses} registration "
                              "${heardAbout.totalResponses == 1 ? "answer" : "answers"} "
                              "in this period.",
                      style: context.listSubtitle,
                    ),
                  ),
                  if (admin.statsHeardAboutLoading)
                    const SizedBox(
                      height: 120,
                      child: Center(
                        child: ToyLibraryLoadingIndicator.compact(),
                      ),
                    )
                  else if (heardAbout != null && heardAbout.data.isNotEmpty)
                    _BarChartCard(rows: heardAbout.data)
                  else
                    const _EmptyChartCard(
                      message: "No heard-about-us answers in this period.",
                    ),
                  const SizedBox(height: 8),
                  const SectionHeader("Catalog by category"),
                  if (catalog != null && catalog.byCategory.isNotEmpty)
                    _PieChartCard(
                      rows: catalog.byCategory.take(8).toList(),
                    )
                  else
                    const _EmptyChartCard(message: "No catalog data."),
                  const SizedBox(height: 8),
                  const SectionHeader("Toys by popularity"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      "Most checked-out toys in this period.",
                      style: context.listSubtitle,
                    ),
                  ),
                  if (popularity != null && popularity.data.isNotEmpty)
                    _ToyPopularityCard(rows: popularity.data)
                  else
                    const _EmptyChartCard(
                      message: "No toy checkouts in this period.",
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsFilterPanel extends StatelessWidget {
  const _StatsFilterPanel({
    required this.period,
    required this.periodLabel,
    required this.sessionDateInput,
    required this.sessionDateFocus,
    required this.sessionDateError,
    required this.year,
    required this.month,
    required this.onPeriodChanged,
    required this.onSessionTyped,
    required this.onSessionCalendar,
    required this.onMonthTap,
    required this.onYearTap,
  });

  final String period;
  final String periodLabel;
  final TextEditingController sessionDateInput;
  final FocusNode sessionDateFocus;
  final String? sessionDateError;
  final int year;
  final int month;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onSessionTyped;
  final VoidCallback onSessionCalendar;
  final VoidCallback onMonthTap;
  final VoidCallback onYearTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Period",
            style: context.sectionHeader.copyWith(fontSize: 13, letterSpacing: 0.2),
          ),
          const SizedBox(height: 4),
          Text(periodLabel, style: context.listSubtitle),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              side: BorderSide(color: colors.outlineVariant),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            segments: [
              for (final entry in const [
                ("session", "Session"),
                ("month", "Month"),
                ("year", "Year"),
                ("all", "All"),
              ])
                ButtonSegment(
                  value: entry.$1,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(entry.$2, maxLines: 1),
                  ),
                ),
            ],
            selected: {period},
            onSelectionChanged: (values) => onPeriodChanged(values.first),
          ),
          if (period == "session") ...[
            const SizedBox(height: 10),
            TextField(
              controller: sessionDateInput,
              focusNode: sessionDateFocus,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              keyboardType: TextInputType.datetime,
              decoration: labeledInputDecoration(
                context,
                labelText: "Session day",
                hintText: "dd/mm/yyyy",
                helperText: "Wednesday or Saturday only",
                errorText: sessionDateError,
                suffixIcon: IconButton(
                  tooltip: "Choose from calendar",
                  onPressed: onSessionCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              onSubmitted: (_) => onSessionTyped(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onSessionTyped,
                style: brandFilledButtonStyle(),
                child: const Text("Apply session date"),
              ),
            ),
          ],
          if (period == "month") ...[
            const SizedBox(height: 10),
            _StatsPeriodChip(
              label: "${_monthNames[month - 1]} $year",
              onTap: onMonthTap,
            ),
          ],
          if (period == "year") ...[
            const SizedBox(height: 10),
            _StatsPeriodChip(
              label: "$year",
              onTap: onYearTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsPeriodChip extends StatelessWidget {
  const _StatsPeriodChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBrandYellow, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.listSubtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _monthNames = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

/// Month + year picker for stats filters (clearer than a day calendar).
Future<DateTime?> showMonthYearPicker(
  BuildContext context, {
  required int initialYear,
  required int initialMonth,
  required List<String> monthNames,
}) {
  final firstYear = 2020;
  final lastYear = DateTime.now().year + 1;
  var year = initialYear.clamp(firstYear, lastYear);
  var month = initialMonth.clamp(1, 12);

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Choose month"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  value: year,
                  decoration: labeledInputDecoration(
                    context,
                    labelText: "Year",
                  ),
                  items: [
                    for (var y = firstYear; y <= lastYear; y++)
                      DropdownMenuItem(value: y, child: Text("$y")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => year = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: month,
                  decoration: labeledInputDecoration(
                    context,
                    labelText: "Month",
                  ),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(monthNames[m - 1]),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => month = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(DateTime(year, month)),
                style: brandFilledButtonStyle(),
                child: const Text("Apply"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<int?> showYearPicker(
  BuildContext context, {
  required int initialYear,
}) {
  final firstYear = 2020;
  final lastYear = DateTime.now().year + 1;
  var year = initialYear.clamp(firstYear, lastYear);

  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Choose year"),
            content: DropdownButtonFormField<int>(
              value: year,
              decoration: labeledInputDecoration(
                context,
                labelText: "Year",
              ),
              items: [
                for (var y = firstYear; y <= lastYear; y++)
                  DropdownMenuItem(value: y, child: Text("$y")),
              ],
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => year = value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(year),
                style: brandFilledButtonStyle(),
                child: const Text("Apply"),
              ),
            ],
          );
        },
      );
    },
  );
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({
    required this.overview,
    required this.period,
    required this.sessionDate,
    required this.year,
    required this.month,
    required this.periodLabel,
  });

  final StatsOverview overview;
  final String period;
  final DateTime? sessionDate;
  final int year;
  final int month;
  final String periodLabel;

  void _openPendingMembers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminStatsPendingMembersScreen(
          period: period,
          sessionDate: sessionDate,
          year: year,
          month: month,
          periodLabel: periodLabel,
        ),
      ),
    );
  }

  void _openRevenueBreakdown(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final rows = revenueBreakdownRows(overview);
        return AlertDialog(
          title: const Text("Revenue breakdown"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                periodLabel,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].label,
                        style: context.bodyText,
                      ),
                    ),
                    Text(
                      formatRevenueCents(rows[i].cents),
                      style: context.bodyText.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Total",
                      style: context.cardTitle.copyWith(fontSize: 15),
                    ),
                  ),
                  Text(
                    formatRevenueCents(overview.revenueCents),
                    style: context.cardTitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: brandFilledButtonStyle(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final boundedPeriod = overview.period != "all";
    final cards = [
      _StatCard(
        label: boundedPeriod ? "Members (at end)" : "Members",
        value: "${overview.totalMembers}",
      ),
      _StatCard(label: "New members", value: "${overview.newMembers}"),
      _StatCard(label: "Bookings", value: "${overview.bookings}"),
      _StatCard(label: "Checkouts", value: "${overview.checkouts}"),
      _StatCard(label: "Returns", value: "${overview.returns}"),
      _StatCard(
        label: "Revenue",
        value: formatRevenueCents(overview.revenueCents),
        onTap: () => _openRevenueBreakdown(context),
        hint: "View breakdown",
      ),
      _StatCard(
        label: boundedPeriod ? "Toys loaned" : "Catalog toys",
        value: "${overview.catalogToys}",
      ),
      _StatCard(
        label: "Pending",
        value: formatRevenueCents(overview.pendingRevenueCents),
        onTap: () => _openPendingMembers(context),
        hint: "View members owing",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 520 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 4 ? 1.5 : 1.35,
          children: cards,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.listSubtitle.copyWith(fontSize: 12),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.cardTitle,
        ),
        if (hint != null && onTap != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: context.listSubtitle.copyWith(
              fontSize: 10,
              color: colors.primary,
            ),
          ),
        ],
      ],
    );

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: content,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }
}

class _GroupByChips extends StatelessWidget {
  const _GroupByChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in const [
            ("category", "Category"),
            ("age", "Age"),
            ("manufacturer", "Maker"),
          ])
            _StatsOptionChip(
              label: option.$2,
              selected: value == option.$1,
              onTap: () => onChanged(option.$1),
            ),
        ],
      ),
    );
  }
}

class _StatsOptionChip extends StatelessWidget {
  const _StatsOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? kBrandYellow : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: context.listSubtitle.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.rows});

  final List<StatsCountRow> rows;

  static const _barSlotWidth = 44.0;

  double _yAxisReservedSize(double maxY) {
    final digits = maxY.toInt().toString().length;
    return (digits * 8.0 + 14).clamp(38.0, 52.0);
  }

  @override
  Widget build(BuildContext context) {
    final peak = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);
    final maxY = niceChartMaxY(peak).toDouble();
    final yInterval = niceChartYInterval(maxY.toInt()).toDouble();
    final yReserved = _yAxisReservedSize(maxY);
    final barColor = kBrandYellow.withValues(alpha: 0.85);
    final chartWidth = rows.length * _barSlotWidth + yReserved + 12;
    const axisStyle = TextStyle(fontSize: 9, height: 1.1);

    return _StatsSurfaceCard(
      clipContent: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Tap a bar for the full label",
              style: context.listSubtitle.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      minY: 0,
                      groupsSpace: 10,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => kBrandOnYellow,
                          maxContentWidth: 260,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          tooltipMargin: 6,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final row = rows[group.x.toInt()];
                            return BarTooltipItem(
                              "${row.label}\n${row.count}",
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: yReserved,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value > maxY) {
                                return const SizedBox.shrink();
                              }
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: axisStyle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= rows.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Transform.rotate(
                                  angle: -0.75,
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    chartAxisLabel(rows[index].label, maxLen: 8),
                                    style: axisStyle,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < rows.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: rows[i].count.toDouble(),
                                color: barColor,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({required this.rows});

  final List<StatsCountRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.count);
    final palette = [
      kBrandYellow,
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
      const Color(0xFFEF6C00),
      const Color(0xFF8E24AA),
      const Color(0xFF546E7A),
      const Color(0xFFD81B60),
      const Color(0xFF43A047),
    ];

    return _StatsSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    for (var i = 0; i < rows.length; i++)
                      PieChartSectionData(
                        value: rows[i].count.toDouble(),
                        color: palette[i % palette.length],
                        title: total == 0
                            ? ""
                            : "${((rows[i].count / total) * 100).round()}%",
                        radius: 52,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < rows.length; i++)
                  _LegendDot(
                    color: palette[i % palette.length],
                    label:
                        "${shortCategoryLabel(rows[i].label)} (${rows[i].count})",
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.listSubtitle.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _ToyPopularityCard extends StatelessWidget {
  const _ToyPopularityCard({required this.rows});

  final List<ToyPopularityRow> rows;

  @override
  Widget build(BuildContext context) {
    final peak = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);

    return _StatsSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ToyPopularityRow(
                rank: i + 1,
                row: rows[i],
                maxCount: peak,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToyPopularityRow extends StatelessWidget {
  const _ToyPopularityRow({
    required this.rank,
    required this.row,
    required this.maxCount,
  });

  final int rank;
  final ToyPopularityRow row;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : row.count / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                "$rank.",
                style: context.listSubtitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: context.cardTitle.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "#${row.toyId}",
                    style: context.listSubtitle.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${row.count}",
              style: context.cardTitle.copyWith(fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: kBrandYellow.withValues(alpha: 0.18),
            color: kBrandYellow,
          ),
        ),
      ],
    );
  }
}

class _StatsSurfaceCard extends StatelessWidget {
  const _StatsSurfaceCard({
    required this.child,
    this.clipContent = true,
  });

  final Widget child;
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  const _EmptyChartCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatsSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, style: context.listSubtitle),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

