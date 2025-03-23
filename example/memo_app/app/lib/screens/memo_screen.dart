import 'package:flutter/material.dart';

import 'package:memo_app/models/memo.dart';
import 'package:memo_app/services/memo_service.dart';

/// Memo detail and edit screen
class MemoScreen extends StatefulWidget {
  /// Constructor
  const MemoScreen({required this.memo, required this.memoService, super.key});

  /// Memo to display or edit
  final Memo memo;

  /// Memo service
  final MemoService memoService;

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  /// Title input controller
  late TextEditingController _titleController;

  /// Content input controller
  late TextEditingController _contentController;

  /// Previous memo ID
  String? _lastMemoId;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(MemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update input controllers if memo has changed
    if (widget.memo.id != _lastMemoId) {
      _initControllers();
    }
  }

  /// Initialize input controllers
  void _initControllers() {
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _lastMemoId = widget.memo.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title input
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (value) {
              // Update title
              if (value != widget.memo.title) {
                _updateMemo();
              }
            },
          ),

          const SizedBox(height: 16),

          // Memo creation date
          Text(
            'Created: ${_formatDateTime(widget.memo.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          // Content input
          Expanded(
            child: TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (value) {
                // Update content
                if (value != widget.memo.content) {
                  _updateMemo();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Update memo
  void _updateMemo() {
    // Update after 0.5 seconds from input (prevent continuous updates)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.memoService.updateMemo(
          id: widget.memo.id,
          title: _titleController.text,
          content: _contentController.text,
        );
      }
    });
  }

  /// Format date and time
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
