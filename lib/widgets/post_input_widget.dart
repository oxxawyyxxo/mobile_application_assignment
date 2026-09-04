import 'dart:io';
import 'package:flutter/material.dart';
import '../services/news_service.dart';
import 'package:image_picker/image_picker.dart';

class PostInputWidget extends StatefulWidget {
  final NewsService newsService;

  const PostInputWidget({super.key, required this.newsService});

  @override
  State<PostInputWidget> createState() => _PostInputWidgetState();
}

class _PostInputWidgetState extends State<PostInputWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isAnonymous = false;
  XFile? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() async {
    final draft = await widget.newsService.loadDraft();
    if (mounted && draft.isNotEmpty) {
      setState(() => _controller.text = draft);
    }
  }

  void _handleSubmit() async {
    if (_controller.text.trim().isEmpty && _selectedImage == null) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.newsService.submitPost(
        content: _controller.text,
        imageFile: _selectedImage,
        isAnonymous: _isAnonymous,
      );

      _controller.clear();
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _isAnonymous = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // This will tell you exactly WHY the image is failing (e.g., missing bucket, RLS, etc.)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: (val) => widget.newsService.saveDraft(val),
              decoration: const InputDecoration(hintText: 'What is happening?'),
            ),

            // FIX 1: Convert XFile back to File to display it in the UI
            if (_selectedImage != null) Image.file(File(_selectedImage!.path), height: 100),

            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: () async {
                    final file = await widget.newsService.pickAndCompressImage();

                    // FIX 2: Convert the returned File into an XFile
                    if (file != null) {
                      setState(() => _selectedImage = XFile(file.path));
                    }
                  },
                ),
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val ?? false),
                ),
                const Text('Anonymous'),
                const Spacer(),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}