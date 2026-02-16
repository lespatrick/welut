import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../blocs/image_bloc.dart';
import '../models/models.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'smart_image.dart';

class FileCarousel extends StatelessWidget {
  const FileCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        return Container(
          height: 180,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Files (${state.stagedImages.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'orf', 'cr2', 'nef', 'arw', 'dng', 'raf', 'rw2', 'pef', 'srw', 'kdc', 'mrw', 'dcr'],
                        );
                        if (result != null && context.mounted) {
                          final paths = result.paths.whereType<String>().toList();
                          context.read<ImageBloc>().add(SelectFiles(paths));
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add More'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      ui.PointerDeviceKind.touch,
                      ui.PointerDeviceKind.mouse,
                      ui.PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.stagedImages.length,
                    itemBuilder: (context, index) {
                      final img = state.stagedImages[index];
                      final isActive = state.activeStagedImage?.path == img.path;
                      return _ThumbnailAction(img: img, isActive: isActive);
                    },
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

class _ThumbnailAction extends StatelessWidget {
  final ImageItem img;
  final bool isActive;

  const _ThumbnailAction({required this.img, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () => context.read<ImageBloc>().add(SelectStagedImage(img)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.1),
              width: 2,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: -2,
              )
            ] : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SmartImage(imagePath: img.path, fit: BoxFit.cover),
              if (isActive)
                Container(color: Theme.of(context).primaryColor.withOpacity(0.2)),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => context.read<ImageBloc>().add(ToggleSelection(img.path)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                right: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (img.rating > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          img.rating,
                          (_) => const Icon(Icons.star, size: 8, color: Colors.amber),
                        ),
                      ),
                    Text(
                      p.basename(img.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.white, backgroundColor: Colors.black45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
