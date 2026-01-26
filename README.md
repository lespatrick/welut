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

## License

MIT
