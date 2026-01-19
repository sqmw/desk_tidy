import 'dart:async';
import 'package:flutter/material.dart';
import 'glass.dart';

/// 操作任务状态
enum OperationStatus { pending, running, success, error }

/// 操作任务数据模型
class OperationTask {
  final String id;
  final String label;
  OperationStatus status;
  double progress; // 0.0 - 1.0
  String? message;
  DateTime startTime;
  DateTime? endTime;

  OperationTask({
    required this.id,
    required this.label,
    this.status = OperationStatus.running,
    this.progress = 0.0,
    this.message,
  }) : startTime = DateTime.now();

  bool get isCompleted =>
      status == OperationStatus.success || status == OperationStatus.error;
}

/// 操作管理器单例
class OperationManager extends ChangeNotifier {
  static final OperationManager _instance = OperationManager._();
  static OperationManager get instance => _instance;
  OperationManager._();

  final Map<String, OperationTask> _tasks = {};
  Timer? _cleanupTimer;

  List<OperationTask> get tasks => _tasks.values.toList();
  bool get hasActiveTasks => _tasks.isNotEmpty;

  /// 开始一个新任务
  String startTask(String label) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _tasks[id] = OperationTask(id: id, label: label);
    notifyListeners();
    return id;
  }

  /// 更新任务进度
  void updateProgress(String id, double progress, {String? message}) {
    final task = _tasks[id];
    if (task != null) {
      task.progress = progress.clamp(0.0, 1.0);
      if (message != null) task.message = message;
      notifyListeners();
    }
  }

  /// 完成任务
  void completeTask(String id, {bool success = true, String? message}) {
    final task = _tasks[id];
    if (task != null) {
      task.status = success ? OperationStatus.success : OperationStatus.error;
      task.progress = 1.0;
      task.endTime = DateTime.now();
      if (message != null) task.message = message;
      notifyListeners();
      _scheduleCleanup();
    }
  }

  /// 快捷方法：执行一个瞬时任务
  void quickTask(String label, {bool success = true}) {
    final id = startTask(label);
    completeTask(id, success: success, message: label);
  }

  void _scheduleCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(seconds: 2), () {
      _tasks.removeWhere((_, task) => task.isCompleted);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}

/// 进度条组件
class OperationProgressBar extends StatelessWidget {
  const OperationProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OperationManager.instance,
      builder: (context, _) {
        final tasks = OperationManager.instance.tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            blurSigma: 20,
            opacity: 0.85,
            padding: const EdgeInsets.all(8),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 分段进度条
                SizedBox(
                  height: 6,
                  child: Row(
                    children: tasks.map((task) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: _TaskSegment(task: task),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // 任务标签列表
                SizedBox(
                  height: 20,
                  child: Row(
                    children: tasks.map((task) {
                      return Expanded(
                        child: Tooltip(
                          message: task.message ?? task.label,
                          child: Text(
                            task.label,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskSegment extends StatelessWidget {
  final OperationTask task;
  const _TaskSegment({required this.task});

  Color _getColor(BuildContext context) {
    switch (task.status) {
      case OperationStatus.pending:
        return Colors.grey;
      case OperationStatus.running:
        return Theme.of(context).colorScheme.primary;
      case OperationStatus.success:
        return Colors.green;
      case OperationStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: task.progress,
        backgroundColor: color.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 6,
      ),
    );
  }
}
