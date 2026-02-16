import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/image_bloc.dart';
import 'dart:io';
import '../services/lut_service.dart';
import 'package:path/path.dart' as p;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';

class ImagePreviewArea extends StatelessWidget {
  const ImagePreviewArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        if (state.activeImage == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(
                  'No Image Selected',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'orf', 'cr2', 'nef', 'arw', 'dng'],
                    );
                    if (result != null && context.mounted) {
                      final paths = result.paths.whereType<String>().toList();
                      context.read<ImageBloc>().add(SelectFiles(paths));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(40.0),
          child: Row(
            children: [
              // Original Preview
              Expanded(
                child: _PreviewBox(
                  label: 'Original',
                  child: Image.file(File(state.activeImage!.path), fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 40),
              // Processed Preview (Shader based)
              Expanded(
                child: _PreviewBox(
                  label: 'Processed',
                  child: state.selectedLut == null 
                    ? const Center(child: Text('Select a LUT to preview'))
                    : LutShaderPreview(
                        imagePath: state.activeImage!.path,
                        lutPath: state.selectedLut!.path,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _PreviewBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  }
}

class LutShaderPreview extends StatefulWidget {
  final String imagePath;
  final String lutPath;

  const LutShaderPreview({
    super.key,
    required this.imagePath,
    required this.lutPath,
  });

  @override
  State<LutShaderPreview> createState() => _LutShaderPreviewState();
}

class _LutShaderPreviewState extends State<LutShaderPreview> {
  ui.FragmentProgram? _program;
  ui.Image? _image;
  ui.Image? _lut;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(LutShaderPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath || oldWidget.lutPath != widget.lutPath) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/lut.frag');
      
      String imgPath = widget.imagePath;
      final ext = p.extension(imgPath).toLowerCase();
      if (['.orf', '.cr2', '.nef', '.arw', '.dng'].contains(ext)) {
        // Use a preview-optimized JPEG for RAW
        final tempFile = await LutService.convertRawToJpg(imgPath);
        imgPath = tempFile.path;
      }

      final imgBytes = await File(imgPath).readAsBytes();
      final lutBytes = await File(widget.lutPath).readAsBytes();
      
      final codecImg = await ui.instantiateImageCodec(imgBytes);
      final frameImg = await codecImg.getNextFrame();
      
      final codecLut = await ui.instantiateImageCodec(lutBytes);
      final frameLut = await codecLut.getNextFrame();

      if (mounted) {
        setState(() {
          _program = prog;
          _image = frameImg.image;
          _lut = frameLut.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shader assets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: SpinKitPulse(color: Colors.white24, size: 40));
    }
    
    if (_program == null || _image == null || _lut == null) {
      return Center(
        child: Text(
          'Failed to load preview',
          style: TextStyle(color: Colors.white.withOpacity(0.3)),
        ),
      );
    }

    final double aspectRatio = _image!.width / _image!.height;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CustomPaint(
          size: Size.infinite,
          painter: LutPainter(
            program: _program!,
            image: _image!,
            lut: _lut!,
          ),
        ),
      ),
    );
  }
}

class LutPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image image;
  final ui.Image lut;

  LutPainter({
    required this.program,
    required this.image,
    required this.lut,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    
    // Uniforms: uSize(0,1), uLutLevel(2), uLutWidth(3)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    
    final level = math.pow(lut.width * lut.height, 1 / 3).roundToDouble();
    shader.setFloat(2, level);
    shader.setFloat(3, lut.width.toDouble());

    // Samplers: uImage(0), uLut(1)
    shader.setImageSampler(0, image);
    shader.setImageSampler(1, lut);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(LutPainter oldDelegate) => 
    oldDelegate.image != image || oldDelegate.lut != lut;
}
