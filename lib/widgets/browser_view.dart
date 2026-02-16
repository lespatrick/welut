
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../blocs/image_bloc.dart';
import '../models/models.dart';
import 'smart_image.dart';
import 'export_dialog.dart';

class BrowserView extends StatefulWidget {
  const BrowserView({super.key});

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  bool _showPreview = true;
  double _previewWidth = 400.0;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return BlocListener<ImageBloc, ImageState>(
      listenWhen: (previous, current) => 
        previous.currentFolder != current.currentFolder && current.currentFolder != null,
      listener: (context, state) {
        // Request focus when folder changes so shortcuts work immediately
        _focusNode.requestFocus();
      },
      child: FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: true,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): NavigateImageIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): NavigateImageIntent(-1),
          SingleActivator(LogicalKeyboardKey.digit0): RateImageIntent(0),
          SingleActivator(LogicalKeyboardKey.digit1): RateImageIntent(1),
          SingleActivator(LogicalKeyboardKey.digit2): RateImageIntent(2),
          SingleActivator(LogicalKeyboardKey.digit3): RateImageIntent(3),
          SingleActivator(LogicalKeyboardKey.digit4): RateImageIntent(4),
          SingleActivator(LogicalKeyboardKey.digit5): RateImageIntent(5),
          SingleActivator(LogicalKeyboardKey.numpad0): RateImageIntent(0),
          SingleActivator(LogicalKeyboardKey.numpad1): RateImageIntent(1),
          SingleActivator(LogicalKeyboardKey.numpad2): RateImageIntent(2),
          SingleActivator(LogicalKeyboardKey.numpad3): RateImageIntent(3),
          SingleActivator(LogicalKeyboardKey.numpad4): RateImageIntent(4),
          SingleActivator(LogicalKeyboardKey.numpad5): RateImageIntent(5),
        },
        actions: <Type, Action<Intent>>{
          NavigateImageIntent: CallbackAction<NavigateImageIntent>(
            onInvoke: (intent) {
              final bloc = context.read<ImageBloc>();
              final state = bloc.state;
              final images = state.filteredBrowserImages;
              final currentImage = state.activeBrowserImage;
              
              if (images.isEmpty) return null;
              
              int nextIndex = 0;
              if (currentImage != null) {
                final currentIndex = images.indexWhere((img) => img.path == currentImage.path);
                if (currentIndex != -1) {
                  nextIndex = (currentIndex + intent.direction).clamp(0, images.length - 1);
                }
              }
              
              if (nextIndex >= 0 && nextIndex < images.length) {
                bloc.add(SelectBrowserImage(images[nextIndex]));
              }
              return null;
            },
          ),
          RateImageIntent: CallbackAction<RateImageIntent>(
            onInvoke: (intent) {
              final bloc = context.read<ImageBloc>();
              final currentImage = bloc.state.activeBrowserImage;
              if (currentImage != null) {
                bloc.add(UpdateRating(currentImage.path, intent.rating));
              }
              return null;
            },
          ),
        },
        child: Column(
          children: [
        _BrowserHeader(
          isPreviewVisible: _showPreview,
          onTogglePreview: () => setState(() => _showPreview = !_showPreview),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Expanded(
                    child: BlocBuilder<ImageBloc, ImageState>(
                      builder: (context, state) {
                        final images = state.filteredBrowserImages;
                        if (images.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  state.currentFolder == null ? 'No folder selected' : 'No images found matching filters',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                                ),
                                if (state.currentFolder == null) ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickFolder(context),
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Open Folder'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return _ImageThumbnail(image: images[index]);
                          },
                        );
                      },
                    ),
                  ),
                  if (_showPreview) ...[
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            // Max preview width should leave at least 250px for the grid (200px item + padding)
                            final maxPreviewWidth = constraints.maxWidth - 250;
                            _previewWidth -= details.delta.dx;
                            // Clamp width between reasonable limits
                            if (_previewWidth < 200) _previewWidth = 200;
                            if (_previewWidth > maxPreviewWidth) _previewWidth = maxPreviewWidth;
                          });
                        },
                        child: const VerticalDivider(width: 12, thickness: 1, color: Colors.white10),
                      ),
                    ),
                    SizedBox(
                      width: _previewWidth,
                      child: const _BrowserPreview(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && context.mounted) {
      context.read<ImageBloc>().add(ScanFolder(path));
    }
  }
}

class _BrowserHeader extends StatelessWidget {
  final bool isPreviewVisible;
  final VoidCallback onTogglePreview;

  const _BrowserHeader({
    required this.isPreviewVisible,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Text(
                'BROWSER',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(width: 24),
              if (state.currentFolder != null) ...[
                Expanded(
                  child: Text(
                    state.currentFolder!,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => _pickFolder(context),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Change Folder'),
                ),
              ],
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => context.read<ImageBloc>().add(SelectAll(true)),
                icon: const Icon(Icons.select_all_rounded, size: 18),
                label: const Text('Select All'),
              ),
              TextButton.icon(
                onPressed: () => context.read<ImageBloc>().add(SelectAll(false)),
                icon: const Icon(Icons.deselect_rounded, size: 18),
                label: const Text('Clear'),
              ),
              const Spacer(),
              IconButton(
                onPressed: onTogglePreview,
                icon: Icon(
                  isPreviewVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
                  color: Colors.white.withOpacity(0.6),
                ),
                tooltip: isPreviewVisible ? 'Hide Preview' : 'Show Preview',
              ),
              const SizedBox(width: 16),
              const _RatingFilterGroup(),
              const SizedBox(width: 24),
              _ExportButton(selectedCount: state.stagedImages.length),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null && context.mounted) {
      context.read<ImageBloc>().add(ScanFolder(path));
    }
  }
}

class _ExportButton extends StatelessWidget {
  final int selectedCount;
  const _ExportButton({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: selectedCount == 0 ? null : () => _showExportDialog(context, selectedCount),
      icon: const Icon(Icons.ios_share_rounded, size: 18),
      label: Text('EXPORT ($selectedCount)'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context, int count) async {
    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (context) => ExportDialog(imageCount: count),
    );

    if (options != null && context.mounted) {
      context.read<ImageBloc>().add(ProcessImages(exportOptions: options));
    }
  }
}

class _RatingFilterGroup extends StatelessWidget {
  const _RatingFilterGroup();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FILTER:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(width: 8),
            for (int i = 0; i <= 5; i++)
              _FilterChip(
                label: i == 0 ? 'All' : '$i+',
                isSelected: state.minRating == i,
                onTap: () => context.read<ImageBloc>().add(SetRatingFilter(i)),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final ImageItem image;

  const _ImageThumbnail({required this.image});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<ImageBloc>().add(SelectBrowserImage(image));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SmartImage(imagePath: image.path),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _SelectionCheckbox(image: image),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: _RatingStars(
                        rating: image.rating,
                        onRatingChanged: (newRating) {
                          context.read<ImageBloc>().add(UpdateRating(image.path, newRating));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                image.path.split('/').last,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;
  final Function(int) onRatingChanged;

  const _RatingStars({required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged(starIndex == rating ? 0 : starIndex),
          child: Icon(
            starIndex <= rating ? Icons.star : Icons.star_border,
            size: 16,
            color: starIndex <= rating ? Colors.amber : Colors.white.withOpacity(0.5),
          ),
        );
      }),
    );
  }
}

class _BrowserPreview extends StatelessWidget {
  const _BrowserPreview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        final image = state.activeBrowserImage;
        if (image == null) {
          return const Center(
            child: Text(
              'Select an image to preview',
              style: TextStyle(color: Colors.white24),
            ),
          );
        }

        final isSelected = state.stagedImages.any((img) => img.path == image.path);

        return Container(
          color: Colors.black12,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black26,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SmartImage(
                    imagePath: image.path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                image.path.split('/').last,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: _RatingStars(
                  rating: image.rating,
                  onRatingChanged: (newRating) {
                    context.read<ImageBloc>().add(UpdateRating(image.path, newRating));
                  },
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.read<ImageBloc>().add(ToggleSelection(image.path)),
                icon: Icon(isSelected ? Icons.remove_circle_outline : Icons.add_circle_outline),
                label: Text(isSelected ? 'REMOVE FROM STAGING' : 'ADD TO STAGING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.red.withOpacity(0.2) : Theme.of(context).primaryColor,
                  foregroundColor: isSelected ? Colors.redAccent : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  final ImageItem image;
  const _SelectionCheckbox({required this.image});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<ImageBloc>().add(ToggleSelection(image.path)),
      child: BlocBuilder<ImageBloc, ImageState>(
        builder: (context, state) {
          final isSelected = state.stagedImages.any((img) => img.path == image.path);
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.black45,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.white24 : Colors.white54,
                width: 1.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          );
        },
      ),
    );
  }
}

class NavigateImageIntent extends Intent {
  final int direction;
  const NavigateImageIntent(this.direction);
}

class RateImageIntent extends Intent {
  final int rating;
  const RateImageIntent(this.rating);
}
