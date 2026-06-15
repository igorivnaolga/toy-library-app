import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

/// Scrolls until [keyForId] resolves, optionally using [scrollController] + [listIndex].
Future<bool> scrollToKeyedWidget({
  required String id,
  required GlobalKey? Function(String id) keyForId,
  ScrollController? scrollController,
  int? listIndex,
  double estimatedItemExtent = 200,
  double listIndexHeaderExtent = 0,
  int maxAttempts = 30,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt == 0) {
      await SchedulerBinding.instance.endOfFrame;
    } else {
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 8 ? 80 : 120),
      );
    }

    if (scrollController != null && listIndex != null) {
      await _scrollListToIndex(
        scrollController,
        listIndex: listIndex,
        itemExtent: estimatedItemExtent,
        headerExtent: listIndexHeaderExtent,
        attempt: attempt,
      );
    }

    final target = keyForId(id)?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.12,
      );
      return true;
    }
  }
  return false;
}

Future<void> _scrollListToIndex(
  ScrollController scrollController, {
  required int listIndex,
  required double itemExtent,
  required double headerExtent,
  int attempt = 0,
}) async {
  if (!scrollController.hasClients) return;
  final maxExtent = scrollController.position.maxScrollExtent;
  final baseOffset = listIndex <= 0
      ? 0.0
      : headerExtent + (listIndex - 1) * itemExtent;
  final attemptBoost = attempt * itemExtent * 0.25;
  final roughOffset = (baseOffset + attemptBoost).clamp(0.0, maxExtent);
  if (roughOffset == scrollController.offset && attempt > 0) return;
  await scrollController.animateTo(
    roughOffset,
    duration: Duration(milliseconds: attempt == 0 ? 320 : 220),
    curve: Curves.easeInOut,
  );
  await SchedulerBinding.instance.endOfFrame;
}

Future<bool> scrollToEventCard({
  required String eventId,
  required GlobalKey? Function(String eventId) keyForEvent,
  ScrollController? scrollController,
  int? listIndex,
  double headerExtent = 110,
}) {
  return scrollToKeyedWidget(
    id: eventId,
    keyForId: keyForEvent,
    scrollController: scrollController,
    listIndex: listIndex,
    estimatedItemExtent: 260,
    listIndexHeaderExtent: headerExtent,
  );
}

Future<bool> scrollToSessionCard({
  required String sessionId,
  required GlobalKey? Function(String sessionId) keyForSession,
  ScrollController? scrollController,
  int? listIndex,
}) {
  return scrollToKeyedWidget(
    id: sessionId,
    keyForId: keyForSession,
    scrollController: scrollController,
    listIndex: listIndex,
    estimatedItemExtent: 88,
  );
}

/// Waits for tab/content layout after switching schedule tabs.
Future<void> waitForScheduleTabLayout({int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await SchedulerBinding.instance.endOfFrame;
  }
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<bool> waitForScrollController(
  ScrollController controller, {
  bool expectScrollableContent = false,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await SchedulerBinding.instance.endOfFrame;
    if (!controller.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      continue;
    }
    final position = controller.position;
    if (position.viewportDimension <= 0) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      continue;
    }
    if (!expectScrollableContent || position.maxScrollExtent > 0 || attempt >= 12) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return controller.hasClients &&
      controller.position.viewportDimension > 0;
}
