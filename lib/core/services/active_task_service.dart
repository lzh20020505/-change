import 'package:flutter/foundation.dart';

class ActiveTaskState {
  const ActiveTaskState({
    required this.title,
    required this.progress,
    required this.isCancelling,
  });

  final String title;
  final double? progress;
  final bool isCancelling;
}

class ActiveTaskService {
  ActiveTaskService._();

  static final instance = ActiveTaskService._();

  final ValueNotifier<ActiveTaskState?> state = ValueNotifier(null);

  void start(String title) {
    state.value = ActiveTaskState(
      title: title,
      progress: 0,
      isCancelling: false,
    );
  }

  void updateProgress(double? progress) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state.value = ActiveTaskState(
      title: current.title,
      progress: progress,
      isCancelling: current.isCancelling,
    );
  }

  void markCancelling() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state.value = ActiveTaskState(
      title: current.title,
      progress: current.progress,
      isCancelling: true,
    );
  }

  void finish() {
    state.value = null;
  }
}
