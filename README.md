# Welut

**Welut** is a high-performance desktop application designed for photographers and digital artists to preview and apply Look-Up Tables (LUTs) to their images quickly and efficiently.

## Features

- **Blazing Fast Previews**: instanly preview LUTs on your high-resolution RAW or JPEG images.
- **Support for Multiple Formats**: Works with `.png` Hald CLUTs.
- **Platform Optimized**: Uses native macOS APIs (sips) for speed and Sharp for other platforms.
- **Clean UI**: A minimalist and intuitive interface built with React and Electron.

## Tech Stack

- **Frontend**: React, TypeScript, Vite
- **Backend**: Electron, Node.js
- **Image Processing**: Native macOS `sips`, Sharp, dcraw

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
