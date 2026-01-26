import { useState } from 'react'
import './App.css'
import { LutLibrary } from './components/LutLibrary';
import { Thumbnail } from './components/Thumbnail';

interface LutItem {
  id: string;
  name: string;
  path: string;
}

function App() {
  const [selectedLut, setLutPath] = useState<LutItem | null>(null);
  const [files, setFiles] = useState<string[]>([]);
  const [activeFile, setActiveFile] = useState<string | null>(null);
  const [previewOriginal, setPreviewOriginal] = useState<string | null>(null);
  const [previewLut, setPreviewLut] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);
  const [status, setStatus] = useState<string[]>([]);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [loadingLutPreview, setLoadingLutPreview] = useState(false);


  const handleSelectFiles = async () => {
    const paths = await window.ipcRenderer.invoke('select-files');
    if (paths && paths.length > 0) {
      setFiles(prev => [...new Set([...prev, ...paths])]);
      if (!activeFile) {
        setActiveFile(paths[0]); // Auto-select first new file
        loadPreview(paths[0], selectedLut);
      }
    }
  };

  const handleRemoveFile = (e: React.MouseEvent, pathToRemove: string) => {
    e.stopPropagation();
    const newFiles = files.filter(f => f !== pathToRemove);
    setFiles(newFiles);

    if (activeFile === pathToRemove) {
      if (newFiles.length > 0) {
        const index = files.indexOf(pathToRemove);
        const nextFile = newFiles[index] || newFiles[newFiles.length - 1];
        loadPreview(nextFile, selectedLut);
      } else {
        setActiveFile(null);
        setPreviewOriginal(null);
        setPreviewLut(null);
      }
    }
  };

  const handleLutSelect = (lut: LutItem | null) => {
    setLutPath(lut);
    if (activeFile && lut) {
      updateLutPreview(activeFile, lut);
    } else if (!lut) {
      setPreviewLut(null);
    }
  };

  const loadPreview = async (filePath: string, currentLut: LutItem | null) => {
    setActiveFile(filePath);
    setPreviewOriginal(null);
    setPreviewLut(null);
    setLoadingPreview(true);

    // Load Original
    try {
      const url = await window.ipcRenderer.invoke('get-preview', filePath);
      if (url) {
        setPreviewOriginal(url);
        // If LUT is selected, load that too
        if (currentLut) {
          updateLutPreview(filePath, currentLut);
        }
      }
    } finally {
      setLoadingPreview(false);
    }
  };

  const updateLutPreview = async (filePath: string, lut: LutItem) => {
    setLoadingLutPreview(true);
    try {
      const url = await window.ipcRenderer.invoke('get-lut-preview', filePath, lut.path);
      if (url) {
        setPreviewLut(url);
      }
    } finally {
      setLoadingLutPreview(false);
    }
  };

  const handleProcess = async () => {
    if (!selectedLut || files.length === 0) return;
    setProcessing(true);
    setStatus([]);

    for (const file of files) {
      setStatus(prev => [...prev, `Processing ${file}...`]);
      const result = await window.ipcRenderer.invoke('process-image', file, selectedLut.path);
      if (result.success) {
        setStatus(prev => [...prev, `✅ Saved to ${result.outputPath}`]);
      } else {
        setStatus(prev => [...prev, `❌ Error: ${result.error}`]);
      }
    }
    setProcessing(false);
    setStatus(prev => [...prev, 'Done!']);
  };

  return (
    <div className="main-layout">
      {/* Processing Overlay */}
      {processing && (
        <div className="loading-overlay">
          <h2>Processing Images...</h2>
          <div className="progress-container" style={{ width: '300px', height: '10px', background: '#333', borderRadius: '5px', overflow: 'hidden', margin: '1rem 0' }}>
            <div
              className="progress-bar"
              style={{
                width: `${(status.filter(s => s.startsWith('✅')).length / files.length) * 100}%`,
                height: '100%',
                background: '#646cff',
                transition: 'width 0.3s ease'
              }}
            />
          </div>
          <div className="status-overlay">
            {status.slice(-1)[0]}
          </div>
          <div style={{ marginTop: '0.5rem', color: '#888', fontSize: '0.9rem' }}>
            {status.filter(s => s.startsWith('✅')).length} / {files.length} Completed
          </div>
        </div>
      )}

      {/* Left Column: LUT Library */}
      <aside className="sidebar">
        <LutLibrary
          selectedLutId={selectedLut ? selectedLut.id : null}
          onSelect={handleLutSelect}
        />
      </aside>

      {/* Right Column: Work Area */}
      <main className="main-content">
        {files.length === 0 && (
          <div className="card">
            {/* Add button is now in the carousel card */}
            <div style={{ textAlign: 'center', padding: '2rem' }}>
              <button onClick={handleSelectFiles} disabled={processing}>
                + Add RAW Files
              </button>
            </div>
          </div>
        )}

        {/* Preview Section */}
        <div className="preview-container">
          <div className="preview-box">
            <span className="preview-label">Original</span>
            {loadingPreview ? (
              <div className="spinner"></div>
            ) : previewOriginal ? (
              <img src={previewOriginal} alt="Original" className="preview-image" />
            ) : (
              <p style={{ color: '#666' }}>No Image Selected</p>
            )}
          </div>

          {/* Only show processed box if we have an image */}
          {(previewOriginal || loadingPreview) && (
            <div className="preview-box">
              <span className="preview-label">Processed</span>
              {loadingLutPreview ? (
                <div className="spinner"></div>
              ) : previewLut ? (
                <img src={previewLut} alt="Processed" className="preview-image" />
              ) : (
                <div className="placeholder-preview">
                  {selectedLut ? (loadingPreview ? 'Waiting for original...' : 'Failed to generate') : 'Select a LUT'}
                </div>
              )}
            </div>
          )}
        </div>

        {/* ... Carousel ... */}
        {files.length > 0 && (
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3>Selected Files ({files.length})</h3>
              <button onClick={handleSelectFiles} disabled={processing} style={{ padding: '0.4rem 0.8rem', fontSize: '0.9rem' }}>+ Add More</button>
            </div>

            <div className="carousel-container">
              {files.map((f) => (
                <Thumbnail
                  key={f}
                  path={f}
                  isActive={activeFile === f}
                  onClick={() => loadPreview(f, selectedLut)}
                  onRemove={(e) => handleRemoveFile(e, f)}
                />
              ))}
            </div>
          </div>
        )}

        <div className="actions">
          <button
            onClick={handleProcess}
            disabled={processing || !selectedLut || files.length === 0}
            className="process-btn"
          >
            {processing ? 'Processing...' : selectedLut ? `Apply ${selectedLut.name}` : 'Select a LUT to Apply'}
          </button>
        </div>

        {status.length > 0 && (
          <div className="status">
            {status.map((s, i) => <div key={i}>{s}</div>)}
          </div>
        )}
      </main>
    </div>
  )
}

export default App

