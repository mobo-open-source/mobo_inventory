import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A full-screen viewer for images with pinch-to-zoom capabilities.
class FullImageScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final String title;

  const FullImageScreen({
    super.key,
    required this.imageBytes,
    this.title = 'Image',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(imageBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
