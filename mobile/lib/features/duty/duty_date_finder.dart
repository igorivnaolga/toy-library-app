import "package:flutter/material.dart";

import "../events/schedule_date_finder.dart";

/// Opens the schedule calendar (duty + event markers).
Future<void> findDutyDate(BuildContext context) =>
    findScheduleDate(context, source: ScheduleDateSource.duty);
