import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/models.dart';
import '../services/lut_service.dart';
import '../services/xmp_service.dart';
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

class SelectBrowserImage extends ImageEvent {
  final ImageItem? image;
  SelectBrowserImage(this.image);
  @override
  List<Object?> get props => [image];
}

class SelectStagedImage extends ImageEvent {
  final ImageItem? image;
  SelectStagedImage(this.image);
  @override
  List<Object?> get props => [image];
}

class ProcessImages extends ImageEvent {
  final ExportOptions? exportOptions;
  ProcessImages({this.exportOptions});
  @override
  List<Object?> get props => [exportOptions];
}

class SetOutputDirectory extends ImageEvent {
  final String? directory;
  SetOutputDirectory(this.directory);
  @override
  List<Object?> get props => [directory];
}

class ScanFolder extends ImageEvent {
  final String folderPath;
  ScanFolder(this.folderPath);
  @override
  List<Object?> get props => [folderPath];
}

class UpdateRating extends ImageEvent {
  final String imagePath;
  final int rating;
  UpdateRating(this.imagePath, this.rating);
  @override
  List<Object?> get props => [imagePath, rating];
}

class SetRatingFilter extends ImageEvent {
  final int minRating;
  SetRatingFilter(this.minRating);
  @override
  List<Object?> get props => [minRating];
}

class ToggleSelection extends ImageEvent {
  final String path;
  ToggleSelection(this.path);
  @override
  List<Object?> get props => [path];
}

class SelectAll extends ImageEvent {
  final bool select;
  SelectAll(this.select);
  @override
  List<Object?> get props => [select];
}

class ImageState extends Equatable {
  final List<ImageItem> browserImages;
  final List<ImageItem> stagedImages;
  final ImageItem? activeBrowserImage;
  final ImageItem? activeStagedImage;
  final LutItem? selectedLut;
  final String? outputDirectory;
  final String? currentFolder;
  final int minRating;
  final bool isProcessing;
  final List<String> status;

  const ImageState({
    this.browserImages = const [],
    this.stagedImages = const [],
    this.activeBrowserImage,
    this.activeStagedImage,
    this.selectedLut,
    this.outputDirectory,
    this.currentFolder,
    this.minRating = 0,
    this.isProcessing = false,
    this.status = const [],
  });

  List<ImageItem> get filteredBrowserImages {
    if (minRating == 0) return browserImages;
    return browserImages.where((img) => img.rating >= minRating).toList();
  }

  ImageState copyWith({
    List<ImageItem>? browserImages,
    List<ImageItem>? stagedImages,
    ImageItem? activeBrowserImage,
    bool clearActiveBrowserImage = false,
    ImageItem? activeStagedImage,
    bool clearActiveStagedImage = false,
    LutItem? selectedLut,
    bool clearSelectedLut = false,
    String? outputDirectory,
    bool clearOutputDirectory = false,
    String? currentFolder,
    bool clearCurrentFolder = false,
    int? minRating,
    bool? isProcessing,
    List<String>? status,
  }) {
    return ImageState(
      browserImages: browserImages ?? this.browserImages,
      stagedImages: stagedImages ?? this.stagedImages,
      activeBrowserImage: clearActiveBrowserImage ? null : (activeBrowserImage ?? this.activeBrowserImage),
      activeStagedImage: clearActiveStagedImage ? null : (activeStagedImage ?? this.activeStagedImage),
      selectedLut: clearSelectedLut ? null : (selectedLut ?? this.selectedLut),
      outputDirectory: clearOutputDirectory ? null : (outputDirectory ?? this.outputDirectory),
      currentFolder: clearCurrentFolder ? null : (currentFolder ?? this.currentFolder),
      minRating: minRating ?? this.minRating,
      isProcessing: isProcessing ?? this.isProcessing,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    browserImages, 
    stagedImages, 
    activeBrowserImage, 
    activeStagedImage, 
    selectedLut, 
    outputDirectory, 
    currentFolder, 
    minRating, 
    isProcessing, 
    status
  ];
}

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  ImageBloc() : super(const ImageState()) {
    on<SelectFiles>((event, emit) async {
      final List<ImageItem> stagedImages = List.from(state.stagedImages);
      for (final path in event.paths) {
        final existingIndex = stagedImages.indexWhere((img) => img.path == path);
        if (existingIndex == -1) {
          final rating = await XmpService.getRating(path);
          stagedImages.add(ImageItem(path: path, rating: rating, isSelected: true));
        }
      }
      
      emit(state.copyWith(
        stagedImages: stagedImages,
        activeStagedImage: state.activeStagedImage ?? (stagedImages.isNotEmpty ? stagedImages.firstWhere((img) => event.paths.contains(img.path)) : null),
      ));
    });

    on<ScanFolder>((event, emit) async {
      final dir = Directory(event.folderPath);
      if (!await dir.exists()) return;

      emit(state.copyWith(
        status: ['Scanning folder: ${event.folderPath}...'],
        currentFolder: event.folderPath,
      ));

      final imageExtensions = {'.jpg', '.jpeg', '.png', '.orf', '.cr2', '.nef', '.arw', '.dng', '.raf', '.rw2', '.pef', '.srw', '.kdc', '.mrw', '.dcr'};
      
      final files = dir.listSync();
      final List<ImageItem> newImages = [];
      
      for (final file in files) {
        if (file is File) {
          final ext = p.extension(file.path).toLowerCase();
          if (imageExtensions.contains(ext)) {
            final rating = await XmpService.getRating(file.path);
            newImages.add(ImageItem(path: file.path, rating: rating));
          }
        }
      }

      emit(state.copyWith(
        browserImages: newImages,
        activeBrowserImage: newImages.isNotEmpty ? newImages.first : null,
        clearActiveBrowserImage: newImages.isEmpty,
        status: ['Found ${newImages.length} images.'],
      ));
    });

    on<UpdateRating>((event, emit) async {
      await XmpService.setRating(event.imagePath, event.rating);
      
      final updatedBrowserImages = state.browserImages.map((img) {
        if (img.path == event.imagePath) {
          return img.copyWith(rating: event.rating);
        }
        return img;
      }).toList();

      final updatedStagedImages = state.stagedImages.map((img) {
        if (img.path == event.imagePath) {
          return img.copyWith(rating: event.rating);
        }
        return img;
      }).toList();

      final newState = state.copyWith(
        browserImages: updatedBrowserImages,
        stagedImages: updatedStagedImages,
      );
      
      // If active browser image is now filtered out, pick another one
      ImageItem? newActiveBrowser = newState.activeBrowserImage;
      if (newActiveBrowser != null && newActiveBrowser.path == event.imagePath && event.rating < newState.minRating) {
        final filtered = newState.filteredBrowserImages;
        newActiveBrowser = filtered.isNotEmpty ? filtered.first : null;
      }

      emit(newState.copyWith(
        activeBrowserImage: newActiveBrowser,
        clearActiveBrowserImage: newActiveBrowser == null,
      ));
    });

    on<SetRatingFilter>((event, emit) {
      final newState = state.copyWith(minRating: event.minRating);
      
      ImageItem? newActiveBrowser = newState.activeBrowserImage;
      if (newActiveBrowser != null && newActiveBrowser.rating < event.minRating) {
        final filtered = newState.filteredBrowserImages;
        newActiveBrowser = filtered.isNotEmpty ? filtered.first : null;
      }

      emit(newState.copyWith(
        activeBrowserImage: newActiveBrowser,
        clearActiveBrowserImage: newActiveBrowser == null,
      ));
    });

    on<RemoveFile>((event, emit) {
      final updatedStagedImages = state.stagedImages.where((img) => img.path != event.path).toList();
      ImageItem? newActiveStaged = state.activeStagedImage;
      bool shouldClearActive = false;
      
      if (state.activeStagedImage?.path == event.path) {
        if (updatedStagedImages.isNotEmpty) {
          newActiveStaged = updatedStagedImages.first;
        } else {
          newActiveStaged = null;
          shouldClearActive = true;
        }
      }
      
      emit(state.copyWith(
        stagedImages: updatedStagedImages, 
        activeStagedImage: newActiveStaged,
        clearActiveStagedImage: shouldClearActive,
      ));
    });

    on<SelectLut>((event, emit) {
      emit(state.copyWith(
        selectedLut: event.lut,
        clearSelectedLut: event.lut == null,
      ));
    });

    on<SelectBrowserImage>((event, emit) {
      emit(state.copyWith(
        activeBrowserImage: event.image,
        clearActiveBrowserImage: event.image == null,
      ));
    });

    on<SelectStagedImage>((event, emit) {
      emit(state.copyWith(
        activeStagedImage: event.image,
        clearActiveStagedImage: event.image == null,
      ));
    });

    on<SetOutputDirectory>((event, emit) {
      emit(state.copyWith(
        outputDirectory: event.directory,
        clearOutputDirectory: event.directory == null,
      ));
    });

    on<ToggleSelection>((event, emit) {
      final List<ImageItem> stagedImages = List.from(state.stagedImages);
      final isAlreadyStaged = stagedImages.any((img) => img.path == event.path);
      
      if (isAlreadyStaged) {
        stagedImages.removeWhere((img) => img.path == event.path);
      } else {
        // Find it in browserImages to add it
        final browserImg = state.browserImages.firstWhere((img) => img.path == event.path);
        stagedImages.add(browserImg.copyWith(isSelected: true));
      }
      
      final newState = state.copyWith(stagedImages: stagedImages);
      
      ImageItem? newActiveStaged = newState.activeStagedImage;
      if (isAlreadyStaged && state.activeStagedImage?.path == event.path) {
        newActiveStaged = stagedImages.isNotEmpty ? stagedImages.first : null;
      } else if (!isAlreadyStaged && newActiveStaged == null) {
        newActiveStaged = stagedImages.last;
      }

      emit(newState.copyWith(
        activeStagedImage: newActiveStaged,
        clearActiveStagedImage: newActiveStaged == null,
      ));
    });

    on<SelectAll>((event, emit) {
      final List<ImageItem> stagedImages = List.from(state.stagedImages);
      
      if (event.select) {
        for (final browserImg in state.filteredBrowserImages) {
          if (!stagedImages.any((img) => img.path == browserImg.path)) {
            stagedImages.add(browserImg.copyWith(isSelected: true));
          }
        }
      } else {
        // Remove only the currently visible (filtered) images from staged.
        final filteredPaths = state.filteredBrowserImages.map((img) => img.path).toSet();
        stagedImages.removeWhere((img) => filteredPaths.contains(img.path));
      }
      
      emit(state.copyWith(stagedImages: stagedImages));
    });

    on<ProcessImages>((event, emit) async {
      final targets = state.stagedImages;

      if (state.selectedLut == null || targets.isEmpty) return;
      
      final exportOptions = event.exportOptions;
      final outputDir = exportOptions?.outputDirectory ?? state.outputDirectory;

      if (outputDir == null) return;

      emit(state.copyWith(
        isProcessing: true, 
        status: ['Starting processing ${targets.length} image(s)...'],
        outputDirectory: outputDir,
      ));

      final selectedLut = state.selectedLut!;
      
      try {
        final List<Future<void>> processingTasks = targets.map((imgItem) async {
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
              maxDimension: exportOptions?.maxDimension,
              quality: exportOptions?.quality ?? 90,
            );

            debugPrint('✅ Processed: ${p.basename(imgItem.path)}');
          } catch (e) {
            debugPrint('❌ Error processing ${imgItem.path}: $e');
            throw e;
          }
        }).toList();

        await Future.wait(processingTasks);
        
        emit(state.copyWith(
          status: [...state.status, 'Done! Processed ${targets.length} image(s).'],
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
