import 'package:flutter/material.dart';
import 'package:memo_app/models/memo.dart';
import 'package:memo_app/screens/memo_screen.dart';
import 'package:memo_app/services/memo_service.dart';
import 'package:signals/signals_flutter.dart';

/// App home screen
class HomeScreen extends StatelessWidget {
  /// Constructor
  const HomeScreen({
    required this.memoService,
    required this.connectionStatus,
    super.key,
  });

  /// Memo service
  final MemoService memoService;

  /// Connection status
  final Signal<ConnectionStatus> connectionStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MemoApp'),
        actions: [
          // Connection status indicator
          Watch((context) {
            final status = connectionStatus.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      status == ConnectionStatus.connected
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color:
                          status == ConnectionStatus.connected
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status == ConnectionStatus.connected ? '接続済み' : '未接続',
                      style: TextStyle(
                        color:
                            status == ConnectionStatus.connected
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      body: Row(
        children: [
          // Left side: Memo list
          Expanded(
            child: Watch((context) {
              final memos = memoService.memos.value;
              final selectedId = memoService.selectedMemoId.value;

              if (memos.isEmpty) {
                return const Center(child: Text('No memos. Please create a new memo.'));
              }

              return ListView.builder(
                itemCount: memos.length,
                itemBuilder: (context, index) {
                  final memo = memos[index];
                  final selected = memo.id == selectedId;

                  return ListTile(
                    title: Text(memo.title),
                    subtitle: Text(
                      '${_formatDate(memo.createdAt)} - ${_truncateContent(memo.content)}',
                    ),
                    selected: selected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    onTap: () {
                      memoService.selectMemo(memo.id);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _confirmDelete(context, memo);
                      },
                    ),
                  );
                },
              );
            }),
          ),

          // Center divider
          const VerticalDivider(),

          // Right side: Memo detail/edit
          Expanded(
            flex: 2,
            child: Watch((context) {
              final selectedMemo = memoService.selectedMemo;

              if (selectedMemo == null) {
                return const Center(child: Text('Please select a memo or create a new one.'));
              }

              return MemoScreen(memo: selectedMemo, memoService: memoService);
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewMemo(context),
        tooltip: 'New memo',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Create new memo
  void _createNewMemo(BuildContext context) {
    // Use TextEditingController to manage values
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('New Memo'),
            content: TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter memo title',
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  final memo = memoService.createMemo(title: value);
                  memoService.selectMemo(memo.id);
                  Navigator.of(context).pop();
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final title = titleController.text;

                  if (title.isNotEmpty) {
                    final memo = memoService.createMemo(title: title);
                    memoService.selectMemo(memo.id);
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  /// Confirmation dialog for memo deletion
  void _confirmDelete(BuildContext context, Memo memo) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Memo'),
            content: Text('Are you sure you want to delete "${memo.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  memoService.deleteMemo(memo.id);
                  Navigator.of(context).pop();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Date format
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  /// Truncate content
  String _truncateContent(String content) {
    if (content.isEmpty) {
      return '';
    }
    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }
}

/// 接続状態
enum ConnectionStatus { disconnected, connected }
