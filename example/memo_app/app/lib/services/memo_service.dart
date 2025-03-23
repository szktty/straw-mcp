import 'package:memo_app/models/memo.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

/// Service class responsible for memo operations
class MemoService {
  /// List to store memos in memory
  final memos = listSignal<Memo>([]);

  /// Currently selected memo ID
  final selectedMemoId = signal<String?>(null);

  /// UUID generator
  final _uuid = const Uuid();

  /// Create a memo
  Memo createMemo({required String title, String content = ''}) {
    final memo = Memo(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );

    memos.add(memo);
    return memo;
  }

  /// Update a memo
  Memo updateMemo({required String id, String? title, String? content}) {
    final index = memos.value.indexWhere((memo) => memo.id == id);
    if (index == -1) {
      throw Exception('Memo not found: $id');
    }

    final oldMemo = memos.value[index];
    final newMemo = oldMemo.copyWith(title: title, content: content);

    memos.value = [...memos.value]..replaceRange(index, index + 1, [newMemo]);
    return newMemo;
  }

  /// Delete a memo
  void deleteMemo(String id) {
    final index = memos.value.indexWhere((memo) => memo.id == id);
    if (index == -1) {
      throw Exception('Memo not found: $id');
    }

    // Remove the memo with matching ID
    memos.value = [...memos.value]..removeAt(index);

    // Clear selection if the deleted memo was selected
    if (selectedMemoId.value == id) {
      selectedMemoId.value = null;
    }
  }

  /// Get all memos
  List<Memo> getMemos() {
    return memos.value;
  }

  /// Get a specific memo
  Memo getMemo(String id) {
    final memo = memos.value.firstWhere(
      (memo) => memo.id == id,
      orElse: () => throw Exception('Memo not found: $id'),
    );
    return memo;
  }

  /// Select a memo
  void selectMemo(String? id) {
    selectedMemoId.value = id;
  }

  /// Get the currently selected memo
  Memo? get selectedMemo {
    final id = selectedMemoId.value;
    if (id == null) return null;

    try {
      return getMemo(id);
    } catch (_) {
      return null;
    }
  }
}
