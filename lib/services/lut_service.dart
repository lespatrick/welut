import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class LutService {
  /// Applies a 3D LUT using GPU-accelerated fragment shader.
  static Future<File> applyLut({
    required File sourceImage,
    required File lutImage,
    required String outputPath,
  }) async {
    // 1. Load resources
    final sourceBytes = await sourceImage.readAsBytes();
    final lutBytes = await lutImage.readAsBytes();

    final codecImg = await ui.instantiateImageCodec(sourceBytes);
    final frameImg = await codecImg.getNextFrame();
    final srcImg = frameImg.image;

    final codecLut = await ui.instantiateImageCodec(lutBytes);
    final frameLut = await codecLut.getNextFrame();
    final lutImg = frameLut.image;

    // 2. Load and set up shader
    final program = await ui.FragmentProgram.fromAsset('shaders/lut.frag');
    final shader = program.fragmentShader();

    final double width = srcImg.width.toDouble();
    final double height = srcImg.height.toDouble();

    // Uniforms: uSize(0,1), uLutLevel(2), uLutWidth(3)
    shader.setFloat(0, width);
    shader.setFloat(1, height);
    
    final level = math.pow(lutImg.width * lutImg.height, 1 / 3).roundToDouble();
    shader.setFloat(2, level);
    shader.setFloat(3, lutImg.width.toDouble());

    shader.setImageSampler(0, srcImg);
    shader.setImageSampler(1, lutImg);

    // 3. Render on GPU
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
    final paint = ui.Paint()..shader = shader;
    
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), paint);
    
    final picture = recorder.endRecording();
    final outputImg = await picture.toImage(srcImg.width, srcImg.height);
    
    // 4. Convert to bytes and save (using Isolate for encoding)
    final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception('Failed to get byte data from GPU');

    await compute(_encodeJpgTask, _EncodeParams(
      bytes: byteData.buffer.asUint8List(),
      width: outputImg.width,
      height: outputImg.height,
      outputPath: outputPath,
    ));

    return File(outputPath);
  }

  static Future<void> _encodeJpgTask(_EncodeParams params) async {
    // Convert RGBA to Image object
    final image = img.Image.fromBytes(
      width: params.width,
      height: params.height,
      bytes: params.bytes.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    );
    
    final encoded = img.encodeJpg(image, quality: 90);
    await File(params.outputPath).writeAsBytes(encoded);
  }

  /// Helper for RAW conversion using sips on macOS.
  static Future<File> convertRawToJpg(String inputPath) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('RAW conversion currently supported on macOS only');
    }

    final tempDir = Directory.systemTemp;
    final tempPath = p.join(tempDir.path, 'welut_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final result = await Process.run('sips', [
      '-s', 'format', 'jpeg',
      inputPath,
      '--out', tempPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('sips conversion failed: ${result.stderr}');
    }

    return File(tempPath);
  }
}

class _EncodeParams {
  final Uint8List bytes;
  final int width;
  final int height;
  final String outputPath;

  _EncodeParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.outputPath,
  });
}
