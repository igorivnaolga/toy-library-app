import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "booking_models.dart";

/// Bottom sheet for choosing a Wed/Sat library pickup day.
Future<PickupDateOption?> showPickupDatePickerSheet(
  BuildContext context, {
  required List<PickupDateOption> options,
  String title = "Choose pickup day",
}) {
  return showModalBottomSheet<PickupDateOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: kBrandYellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kBrandOnYellow.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          color: kBrandOnYellow,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _PickupDateOptionTile(
                    option: option,
                    onTap: () => Navigator.of(ctx).pop(option),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kBrandOnYellow,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: kBrandYellow, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                child: const Text("Cancel"),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PickupDateOptionTile extends StatelessWidget {
  const _PickupDateOptionTile({
    required this.option,
    required this.onTap,
  });

  final PickupDateOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSaturday = option.weekday.toLowerCase() == "saturday";
    return Material(
      color: kBrandYellow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: kBrandYellow.withValues(alpha: 0.2),
        highlightColor: kBrandYellow.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kBrandYellow.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSaturday ? Icons.weekend_outlined : Icons.calendar_today,
                  color: kBrandOnYellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: kBrandOnYellow,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sessionHours(option.weekday),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: kBrandOnYellow.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: kBrandOnYellow.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionHours(String weekday) {
  switch (weekday.toLowerCase()) {
    case "wednesday":
      return "1:00 pm – 2:30 pm";
    case "saturday":
      return "11:30 am – 2:00 pm";
    default:
      return "";
  }
}
