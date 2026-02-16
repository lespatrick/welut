# Welut

**Welut** is a high-performance desktop application designed for photographers and digital artists to preview and apply Look-Up Tables (LUTs) to their images quickly and efficiently.

## Features

- **Two-Mode Interface**: 
  - **Browser Mode**: Easily navigate folders, preview images in a grid, and organize your library.
  - **LUT Mode**: Apply professional film simulation LUTs with real-time GPU-accelerated previews.
- **Batch Export**: Select multiple images from the browser and export them all at once.
- **Advanced Export Options**: Downscale images by limiting max dimensions and control JPEG compression quality.
- **XMP Rating System**: Store image ratings (0-5 stars) in standard XMP sidecar files, compatible with Lightroom and other industry tools.
- **Fast Filtering**: Filter your view by rating to focus on your best shots.
- **Blazing Fast Previews**: Instantly preview LUTs on high-resolution RAW or JPEG images using GPU fragment shaders.
- **RAW Support**: Native support for most RAW formats (ORF, CR2, NEF, ARW, DNG, etc.) via macOS `sips`.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Image Processing**: GPU-accelerated Fragment Shaders (GLSL), `image` package
- **Native Integration**: macOS `sips` for RAW conversion

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Build the application
npm run build
```

## LUT License

The included film simulation LUTs are from the **RawTherapee Film Simulation Collection** (version 2015-09-20) and are licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

**Credits:**
- Pat David
- Pavlov Dmitry
- Michael Ezra

The trademarked names in the LUT filenames (Agfa, Fuji, Kodak, Lomography, Polaroid) are used for informational purposes only to indicate which film stock each LUT approximates. This constitutes fair use. We are not affiliated with or endorsed by these trademark owners.

Learn more about Hald CLUTs:
- [RawPedia - Film Simulation](http://rawpedia.rawtherapee.com/Film_Simulation)
- [Hald CLUT Technology](http://www.quelsolaar.com/technology/clut.html)

## License

MIT
