import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/image_bloc.dart';
import 'lut_library.dart';
import 'image_preview_area.dart';
import 'file_carousel.dart';
import 'processing_overlay.dart';
import 'browser_view.dart';
import 'export_dialog.dart';
import '../models/models.dart';
import 'package:file_picker/file_picker.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: 'Licenses',
              onSelected: () {
                showLicensePage(
                  context: context,
                  applicationName: 'WebLut',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ],
        ),
      ],
      child: DefaultTabController(
        length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: const SafeArea(
              child: TabBar(
                isScrollable: true,
                indicatorColor: Color(0xFF646CFF),
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'BROWSER'),
                  Tab(text: 'LUT MODE'),
                ],
              ),
            ),
          ),
        ),
        body: const Stack(
          children: [
            TabBarView(
              children: [
                BrowserView(),
                _LutModeLayout(),
              ],
            ),
            // Processing Overlay
            ProcessingOverlay(),
          ],
        ),
      ),
    ));
  }
}

class _LutModeLayout extends StatelessWidget {
  const _LutModeLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar: LUT Library
        const SizedBox(
          width: 280,
          child: LutLibrary(),
        ),
        // Main content: Preview and Carousel
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Column(
              children: [
                // Preview Area
                Expanded(
                  child: ImagePreviewArea(),
                ),
                // Carousel Area
                FileCarousel(),
                // Bottom Actions
                _ActionBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        final stagedCount = state.stagedImages.length;
        final canProcess = stagedCount > 0 && state.selectedLut != null && !state.isProcessing;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Output Directory Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OUTPUT DIRECTORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final path = await FilePicker.platform.getDirectoryPath();
                        if (path != null && context.mounted) {
                          context.read<ImageBloc>().add(SetOutputDirectory(path));
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 16,
                            color: Theme.of(context).primaryColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.outputDirectory ?? 'Not selected (Click to choose)',
                              style: TextStyle(
                                fontSize: 13,
                                color: state.outputDirectory != null 
                                  ? Colors.white.withOpacity(0.9) 
                                  : Theme.of(context).primaryColor.withOpacity(0.7),
                                fontWeight: state.outputDirectory != null ? FontWeight.w500 : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: canProcess ? () async {
                  final count = state.stagedImages.length;
                  
                  final options = await showDialog<ExportOptions>(
                    context: context,
                    builder: (context) => ExportDialog(imageCount: count),
                  );

                  if (options != null && context.mounted) {
                    context.read<ImageBloc>().add(ProcessImages(exportOptions: options));
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  state.isProcessing 
                    ? 'Processing...' 
                    : state.selectedLut != null 
                      ? 'Process ${state.stagedImages.length} Image${state.stagedImages.length > 1 ? 's' : ''}' 
                      : 'Select a LUT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
