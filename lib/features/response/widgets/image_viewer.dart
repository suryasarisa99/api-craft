import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageViewer extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageViewer({super.key, required this.imageBytes});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final Future<ui.Image> _imageFuture;
  late final Image _image;

  @override
  void initState() {
    super.initState();
    _loadImg();
  }

  void _loadImg() {
    _image = _buildImg();
    Completer<ui.Image> completer = Completer<ui.Image>();
    _image.image
        .resolve(ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool synchronousCall) {
            completer.complete(info.image);
          }),
        );
    _imageFuture = completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: .start,
      children: [
        Row(
          children: [
            const Icon(Icons.image, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Image Viewer',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Spacer(),
            _buildDimmensions(),
          ],
        ),
        Expanded(child: InteractiveViewer(maxScale: 10, child: _buildImg())),
      ],
    );
  }

  Image _buildImg() {
    return Image.memory(widget.imageBytes);
  }

  Widget _buildDimmensions() {
    return FutureBuilder(
      future: _imageFuture,
      builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
        if (snapshot.hasData) {
          return Text('${snapshot.data!.width}x${snapshot.data!.height}');
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }
}
