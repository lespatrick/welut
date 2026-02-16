import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/image_bloc.dart';
import 'lut_library.dart';
import 'image_preview_area.dart';
import 'file_carousel.dart';
import 'processing_overlay.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
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
                  child: Column(
                    children: [
                      // Preview Area
                      const Expanded(
                        child: ImagePreviewArea(),
                      ),
                      // Carousel Area
                      const FileCarousel(),
                      // Bottom Actions
                      const _ActionBar(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Processing Overlay
          const ProcessingOverlay(),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        final canProcess = state.images.isNotEmpty && state.selectedLut != null && !state.isProcessing;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: canProcess ? () => context.read<ImageBloc>().add(ProcessImages()) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  state.isProcessing 
                    ? 'Processing...' 
                    : state.selectedLut != null 
                      ? 'Apply ${state.selectedLut!.name}' 
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
