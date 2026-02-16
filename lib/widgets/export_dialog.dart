import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../blocs/image_bloc.dart';
import '../models/models.dart';

class ExportDialog extends StatefulWidget {
  final int imageCount;

  const ExportDialog({super.key, required this.imageCount});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final _maxDimensionController = TextEditingController();
  double _quality = 90;
  String? _outputDirectory;
  bool _useResizing = false;

  @override
  void initState() {
    super.initState();
    _outputDirectory = context.read<ImageBloc>().state.outputDirectory;
  }

  @override
  void dispose() {
    _maxDimensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.ios_share_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'EXPORT ${widget.imageCount} IMAGE${widget.imageCount > 1 ? 'S' : ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Output Folder
            _SectionTitle(title: 'OUTPUT FOLDER'),
            const SizedBox(height: 8),
            _PathPicker(
              path: _outputDirectory,
              onTap: () async {
                final path = await FilePicker.platform.getDirectoryPath();
                if (path != null) setState(() => _outputDirectory = path);
              },
            ),
            const SizedBox(height: 24),

            // Resizing
            Row(
              children: [
                const Expanded(child: _SectionTitle(title: 'RESIZING')),
                Switch(
                  value: _useResizing,
                  onChanged: (v) => setState(() => _useResizing = v),
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: _useResizing ? 1.0 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _maxDimensionController,
                          enabled: _useResizing,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max Width / Height (px)',
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('px', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PresetButton(
                        label: '3MP',
                        dimension: '2100',
                        enabled: _useResizing,
                        onPressed: () => _maxDimensionController.text = '2100',
                      ),
                      const SizedBox(width: 8),
                      _PresetButton(
                        label: '6MP',
                        dimension: '3000',
                        enabled: _useResizing,
                        onPressed: () => _maxDimensionController.text = '3000',
                      ),
                      const SizedBox(width: 8),
                      _PresetButton(
                        label: '12MP',
                        dimension: '4200',
                        enabled: _useResizing,
                        onPressed: () => _maxDimensionController.text = '4200',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quality
            _SectionTitle(title: 'JPEG QUALITY (${_quality.toInt()}%)'),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: Colors.white,
                overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Slider(
                value: _quality,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) => setState(() => _quality = v),
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _outputDirectory == null ? null : () {
                    final options = ExportOptions(
                      outputDirectory: _outputDirectory!,
                      maxDimension: _useResizing ? int.tryParse(_maxDimensionController.text) : null,
                      quality: _quality.toInt(),
                    );
                    Navigator.pop(context, options);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('START EXPORT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final String dimension;
  final bool enabled;
  final VoidCallback onPressed;

  const _PresetButton({
    required this.label,
    required this.dimension,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
            Text('$dimension px', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.3))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.4),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PathPicker extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;

  const _PathPicker({this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                path ?? 'Click to select output folder',
                style: TextStyle(
                  color: path != null ? Colors.white : Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
