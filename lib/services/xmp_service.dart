import 'dart:io';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

class XmpService {
  static const String xmpExtension = '.xmp';

  /// Reads the rating from an XMP sidecar file if it exists.
  /// Returns 0 if no rating is found or file doesn't exist.
  static Future<int> getRating(String imagePath) async {
    final xmpFile = File('$imagePath$xmpExtension');
    if (!await xmpFile.exists()) return 0;

    try {
      final content = await xmpFile.readAsString();
      final document = XmlDocument.parse(content);
      
      // Look for xmp:Rating
      final ratingElement = document.findAllElements('xmp:Rating').firstOrNull;
      if (ratingElement != null) {
        return int.tryParse(ratingElement.innerText) ?? 0;
      }

      // Sometimes it's an attribute in rdf:Description
      final description = document.findAllElements('rdf:Description').firstOrNull;
      if (description != null) {
        final ratingAttr = description.getAttribute('xmp:Rating');
        if (ratingAttr != null) {
          return int.tryParse(ratingAttr) ?? 0;
        }
      }
    } catch (e) {
      print('Error reading XMP for $imagePath: $e');
    }
    return 0;
  }

  /// Writes the rating to an XMP sidecar file.
  static Future<void> setRating(String imagePath, int rating) async {
    final xmpPath = '$imagePath$xmpExtension';
    final xmpFile = File(xmpPath);
    
    String content;
    if (await xmpFile.exists()) {
      content = await xmpFile.readAsString();
      final document = XmlDocument.parse(content);
      
      var description = document.findAllElements('rdf:Description').firstOrNull;
      if (description == null) {
        // Fallback: create a basic doc if structure is weird
        content = _createBasicXmp(rating);
      } else {
        description.setAttribute('xmp:Rating', rating.toString());
        content = document.toXmlString(pretty: true);
      }
    } else {
      content = _createBasicXmp(rating);
    }

    await xmpFile.writeAsString(content);
  }

  static String _createBasicXmp(int rating) {
    return '''
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.6-c140 79.160451, 2017/05/06-01:08:21        ">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""
    xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    xmp:Rating="$rating"/>
 </rdf:RDF>
</x:xmpmeta>
''';
  }
}
