import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/image_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        if (!state.isProcessing) return const SizedBox.shrink();

        final completedCount = state.status.where((s) => s.startsWith('✅')).length;
        final totalCount = state.stagedImages.length;
        final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

        return Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpinKitDoubleBounce(color: Color(0xFF646CFF), size: 50),
                  const SizedBox(height: 32),
                  const Text(
                    'Processing Images...',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF646CFF)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(progress * 100).toInt()}% • $completedCount / $totalCount Completed',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: state.status.length,
                      itemBuilder: (context, index) {
                        final status = state.status[state.status.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: status.startsWith('❌') ? Colors.redAccent : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
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
