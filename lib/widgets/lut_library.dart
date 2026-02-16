import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/image_bloc.dart';
import '../models/models.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class LutLibrary extends StatefulWidget {
  const LutLibrary({super.key});

  @override
  State<LutLibrary> createState() => _LutLibraryState();
}

class _LutLibraryState extends State<LutLibrary> {
  final List<String> _categories = ['Agfa', 'Fuji', 'Kodak', 'Lomography', 'Polaroid'];
  Map<String, List<LutItem>> _categoryLuts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllLuts();
  }

  Future<void> _loadAllLuts() async {
    final rootPath = 'resources/luts';
    Map<String, List<LutItem>> grouped = {};

    for (var cat in _categories) {
      final categoryDir = Directory(p.join(rootPath, cat));
      if (await categoryDir.exists()) {
        final List<LutItem> items = [];
        try {
          await for (var entity in categoryDir.list()) {
            if (entity is File && p.extension(entity.path).toLowerCase() == '.png') {
              items.add(LutItem(
                id: entity.path,
                name: p.basenameWithoutExtension(entity.path),
                path: entity.path,
              ));
            }
          }
          items.sort((a, b) => a.name.compareTo(b.name));
          grouped[cat] = items;
        } catch (e) {
          debugPrint('Error listing directory $cat: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _categoryLuts = grouped;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Library',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, catIndex) {
                      final category = _categories[catIndex];
                      final luts = _categoryLuts[category] ?? [];
                      if (luts.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          ...luts.map((lut) => _LutTile(lut: lut)),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LutTile extends StatelessWidget {
  final LutItem lut;
  const _LutTile({required this.lut});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        final isSelected = state.selectedLut?.id == lut.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () => context.read<ImageBloc>().add(SelectLut(lut)),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        isSelected ? Icons.check : Icons.grid_view_rounded,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lut.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
