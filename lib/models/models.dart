import 'package:equatable/equatable.dart';

class ImageItem extends Equatable {
  final String path;
  final String? previewUrl;
  final bool isProcessing;

  const ImageItem({
    required this.path,
    this.previewUrl,
    this.isProcessing = false,
  });

  ImageItem copyWith({
    String? path,
    String? previewUrl,
    bool? isProcessing,
  }) {
    return ImageItem(
      path: path ?? this.path,
      previewUrl: previewUrl ?? this.previewUrl,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [path, previewUrl, isProcessing];
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
