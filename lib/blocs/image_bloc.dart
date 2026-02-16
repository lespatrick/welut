import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/models.dart';
import '../services/lut_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

abstract class ImageEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SelectFiles extends ImageEvent {
  final List<String> paths;
  SelectFiles(this.paths);
  @override
  List<Object?> get props => [paths];
}

class RemoveFile extends ImageEvent {
  final String path;
  RemoveFile(this.path);
  @override
  List<Object?> get props => [path];
}

class SelectLut extends ImageEvent {
  final LutItem? lut;
  SelectLut(this.lut);
  @override
  List<Object?> get props => [lut];
}

class SelectActiveImage extends ImageEvent {
  final ImageItem image;
  SelectActiveImage(this.image);
  @override
  List<Object?> get props => [image];
}

class ProcessImages extends ImageEvent {
  final String? outputDirectory;
  ProcessImages({this.outputDirectory});
  @override
  List<Object?> get props => [outputDirectory];
}

class SetOutputDirectory extends ImageEvent {
  final String? directory;
  SetOutputDirectory(this.directory);
  @override
  List<Object?> get props => [directory];
}

class ImageState extends Equatable {
  final List<ImageItem> images;
  final ImageItem? activeImage;
  final LutItem? selectedLut;
  final String? outputDirectory;
  final bool isProcessing;
  final List<String> status;

  const ImageState({
    this.images = const [],
    this.activeImage,
    this.selectedLut,
    this.outputDirectory,
    this.isProcessing = false,
    this.status = const [],
  });

  ImageState copyWith({
    List<ImageItem>? images,
    ImageItem? activeImage,
    bool clearActiveImage = false,
    LutItem? selectedLut,
    bool clearSelectedLut = false,
    String? outputDirectory,
    bool clearOutputDirectory = false,
    bool? isProcessing,
    List<String>? status,
  }) {
    return ImageState(
      images: images ?? this.images,
      activeImage: clearActiveImage ? null : (activeImage ?? this.activeImage),
      selectedLut: clearSelectedLut ? null : (selectedLut ?? this.selectedLut),
      outputDirectory: clearOutputDirectory ? null : (outputDirectory ?? this.outputDirectory),
      isProcessing: isProcessing ?? this.isProcessing,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [images, activeImage, selectedLut, outputDirectory, isProcessing, status];
}

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  ImageBloc() : super(const ImageState()) {
    on<SelectFiles>((event, emit) {
      final newImages = event.paths.map((p) => ImageItem(path: p)).toList();
      final updatedImages = [...state.images, ...newImages];
      emit(state.copyWith(
        images: updatedImages,
        activeImage: state.activeImage ?? newImages.first,
      ));
    });

    on<RemoveFile>((event, emit) {
      final updatedImages = state.images.where((img) => img.path != event.path).toList();
      ImageItem? newActive = state.activeImage;
      bool shouldClearActive = false;
      
      if (state.activeImage?.path == event.path) {
        if (updatedImages.isNotEmpty) {
          newActive = updatedImages.first;
        } else {
          newActive = null;
          shouldClearActive = true;
        }
      }
      
      emit(state.copyWith(
        images: updatedImages, 
        activeImage: newActive,
        clearActiveImage: shouldClearActive,
      ));
    });

    on<SelectLut>((event, emit) {
      emit(state.copyWith(
        selectedLut: event.lut,
        clearSelectedLut: event.lut == null,
      ));
    });

    on<SelectActiveImage>((event, emit) {
      emit(state.copyWith(activeImage: event.image));
    });

    on<SetOutputDirectory>((event, emit) {
      emit(state.copyWith(
        outputDirectory: event.directory,
        clearOutputDirectory: event.directory == null,
      ));
    });

    on<ProcessImages>((event, emit) async {
      if (state.selectedLut == null || state.images.isEmpty) return;
      
      final outputDir = event.outputDirectory ?? state.outputDirectory;
      if (outputDir == null) return; // Should be handled by UI picker before firing

      emit(state.copyWith(
        isProcessing: true, 
        status: ['Starting processing (GPU Accelerated)...'],
        outputDirectory: outputDir,
      ));

      final selectedLut = state.selectedLut!;
      
      try {
        final List<Future<void>> processingTasks = state.images.map((imgItem) async {
          try {
            File source = File(imgItem.path);
            final ext = p.extension(imgItem.path).toLowerCase();
            final rawExtensions = {'.orf', '.cr2', '.nef', '.arw', '.dng', '.raf', '.rw2', '.pef', '.srw', '.kdc', '.mrw', '.dcr'};
            if (rawExtensions.contains(ext)) {
              source = await LutService.convertRawToJpg(imgItem.path);
            }

            final outputPath = p.join(
              outputDir, 
              '${p.basenameWithoutExtension(imgItem.path)}_welut.jpg'
            );
            
            await LutService.applyLut(
              sourceImage: source,
              lutImage: File(selectedLut.path),
              outputPath: outputPath,
            );

            debugPrint('✅ Processed: ${p.basename(imgItem.path)}');
          } catch (e) {
            debugPrint('❌ Error processing ${imgItem.path}: $e');
            throw e;
          }
        }).toList();

        await Future.wait(processingTasks);
        
        emit(state.copyWith(
          status: [...state.status, 'Done! GPU processing complete. Files saved to: $outputDir'],
          isProcessing: false,
        ));
      } catch (e) {
        emit(state.copyWith(
          status: [...state.status, '❌ Batch Error: $e'],
          isProcessing: false,
        ));
      }
    });
  }
}
