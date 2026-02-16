import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/lut_service.dart';

class SmartImage extends StatefulWidget {
  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SmartImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  String? _displayPath;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _processImage();
    }
  }

  Future<void> _processImage() async {
    final ext = p.extension(widget.imagePath).toLowerCase();
    final rawExtensions = {'.orf', '.cr2', '.nef', '.arw', '.dng', '.raf', '.rw2', '.pef', '.srw', '.kdc', '.mrw', '.dcr'};
    final isRaw = rawExtensions.contains(ext);

    if (!isRaw) {
      if (mounted) {
        setState(() {
          _displayPath = widget.imagePath;
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      debugPrint('SmartImage: Processing RAW image: ${widget.imagePath}');
      final convertedFile = await LutService.convertRawToJpg(widget.imagePath);
      if (mounted) {
        setState(() {
          _displayPath = convertedFile.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('SmartImage: Error processing RAW: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: SpinKitPulse(color: Colors.white24, size: 24));
    }

    if (_error != null) {
      return Center(
        child: Icon(Icons.error_outline, color: Colors.red.withOpacity(0.5)),
      );
    }

    if (_displayPath == null) {
      return const SizedBox.shrink();
    }

    return Image.file(
      File(_displayPath!),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.2)),
        );
      },
    );
  }
}
