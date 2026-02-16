import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'blocs/image_bloc.dart';
import 'widgets/main_layout.dart';

void main() {
  runApp(const WelutApp());
}

class WelutApp extends StatelessWidget {
  const WelutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ImageBloc(),
      child: MaterialApp(
        title: 'welut',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF646CFF),
          scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          textTheme: GoogleFonts.outfitTextTheme(
            ThemeData.dark().textTheme,
          ),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF646CFF),
            secondary: Color(0xFF747BFF),
            surface: Color(0xFF242424),
          ),
        ),
        home: const MainLayout(),
      ),
    );
  }
}
