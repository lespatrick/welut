import 'package:equatable/equatable.dart';

class ImageItem extends Equatable {
  final String path;
  final String? previewUrl;
  final bool isProcessing;
  final int rating;
  final bool isSelected;

  const ImageItem({
    required this.path,
    this.previewUrl,
    this.isProcessing = false,
    this.rating = 0,
    this.isSelected = false,
  });

  ImageItem copyWith({
    String? path,
    String? previewUrl,
    bool? isProcessing,
    int? rating,
    bool? isSelected,
  }) {
    return ImageItem(
      path: path ?? this.path,
      previewUrl: previewUrl ?? this.previewUrl,
      isProcessing: isProcessing ?? this.isProcessing,
      rating: rating ?? this.rating,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [path, previewUrl, isProcessing, rating, isSelected];
}

class LutItem extends Equatable {
  final String id;
  final String name;
  final String path;

  const LutItem({
    required this.id,
    required this.name,
    required this.path,
  });

  @override
  List<Object?> get props => [id, name, path];
}

class ExportOptions extends Equatable {
  final int? maxDimension;
  final int quality;
  final String outputDirectory;

  const ExportOptions({
    this.maxDimension,
    this.quality = 90,
    required this.outputDirectory,
  });

  @override
  List<Object?> get props => [maxDimension, quality, outputDirectory];
}
