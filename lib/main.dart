import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'blocs/image_bloc.dart';
import 'widgets/main_layout.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['RawTherapee Film Simulation Collection'],
      '''
RawTherapee Film Simulation Collection version 2015-09-20
CC BY-SA 4.0

This archive contains a collection of film simulation profiles in the Hald Color Look-Up Table pattern (Hald CLUT). Unless otherwise noted in the filename, they are all in the sRGB color space, 8-bit per channel, in the PNG image format. Most of them are designed to mimic the results of various film stocks, pushed and pulled in various ways or faded over time.

Apply these images to your photos in Hald CLUT-capable software such as RawTherapee to instantly match the colors of your photo to the chosen reference.

Use the level 12 pattern Hald_CLUT_Identity_12.tif to create your own profiles, see the RawPedia article to find out how.

Learn more about Hald CLUTs here:
http://rawpedia.rawtherapee.com/Film_Simulation
http://www.quelsolaar.com/technology/clut.html
http://blog.patdavid.net/2013/08/film-emulation-presets-in-gmic-gimp.html
http://blog.patdavid.net/2013/09/film-emulation-presets-in-gmic-gimp.html

Credits:
Pat David - http://rawtherapee.com/forum/memberlist.php?mode=viewprofile&u=5101
Pavlov Dmitry - http://rawtherapee.com/forum/memberlist.php?mode=viewprofile&u=5592
Michael Ezra - http://rawtherapee.com/forum/memberlist.php?mode=viewprofile&u=1442

Disclaimer:
The trademarked names which may appear in the filenames of the Hald CLUT images are there for informational purposes only. They serve only to inform the user which film stock the given Hald CLUT image is designed to approximate. As there is no way to convey this information other than by using the trademarked name, we believe this constitutes fair use. Neither the publisher nor the authors are affiliated with or endorsed by the companies that own the trademarks.
''',
    );
  });
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
