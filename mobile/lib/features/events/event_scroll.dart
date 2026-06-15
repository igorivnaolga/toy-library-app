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
  int maxAttempts = 25,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt == 0) {
      await SchedulerBinding.instance.endOfFrame;
    } else {
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 6 ? 80 : 120),
      );
    }

    if (scrollController != null && listIndex != null) {
      await _scrollListToIndex(
        scrollController,
        listIndex: listIndex,
        itemExtent: estimatedItemExtent,
        headerExtent: listIndexHeaderExtent,
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
  return scrollController != null &&
      listIndex != null &&
      scrollController.hasClients;
}

Future<void> _scrollListToIndex(
  ScrollController scrollController, {
  required int listIndex,
  required double itemExtent,
  required double headerExtent,
}) async {
  if (!scrollController.hasClients) return;
  final maxExtent = scrollController.position.maxScrollExtent;
  final itemOffset = listIndex <= 0
      ? 0.0
      : headerExtent + (listIndex - 1) * itemExtent;
  final roughOffset = itemOffset.clamp(0.0, maxExtent);
  await scrollController.animateTo(
    roughOffset,
    duration: const Duration(milliseconds: 320),
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

Future<bool> waitForScrollController(ScrollController controller) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await SchedulerBinding.instance.endOfFrame;
    if (controller.hasClients) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return controller.hasClients;
}
