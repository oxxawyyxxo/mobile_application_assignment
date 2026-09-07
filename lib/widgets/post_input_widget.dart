import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/news_service.dart';

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

  String? _locationName;
  bool _isLoadingLocation = false;

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

  Future<void> _fetchLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Permission permanently denied.');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationName = '${place.locality}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoadingLocation = false);
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
        locationName: _locationName,
      );

      _controller.clear();
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _isAnonymous = false;
          _locationName = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: (val) => widget.newsService.saveDraft(val),
              decoration: const InputDecoration(hintText: 'What is happening?'),
            ),

            if (_selectedImage != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.file(File(_selectedImage!.path), height: 100),
            ),

            if (_locationName != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(_locationName!, style: const TextStyle(color: Colors.blue)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _locationName = null),
                  )
                ],
              ),
            ),

            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: () async {
                    final file = await widget.newsService.pickAndCompressImage();
                    if (file != null) setState(() => _selectedImage = XFile(file.path));
                  },
                ),
                IconButton(
                  icon: _isLoadingLocation
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.location_on_outlined),
                  onPressed: _isLoadingLocation ? null : _fetchLocation,
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