import { useState, useEffect } from 'react';

interface ThumbnailProps {
    path: string;
    isActive: boolean;
    onClick: () => void;
    onRemove: (e: React.MouseEvent) => void;
}

export function Thumbnail({ path, isActive, onClick, onRemove }: ThumbnailProps) {
    const [src, setSrc] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let mounted = true;
        const loadThumbnail = async () => {
            try {
                // Request a small thumbnail (150px)
                const url = await window.ipcRenderer.invoke('get-preview', path, 150);
                if (mounted && url) {
                    setSrc(url);
                }
            } catch (e) {
                console.error('Failed to load thumbnail', e);
            } finally {
                if (mounted) setLoading(false);
            }
        };

        loadThumbnail();
        return () => { mounted = false; };
    }, [path]);

    const filename = path.split('/').pop() || path;

    return (
        <div
            className={`thumbnail-item ${isActive ? 'active' : ''}`}
            onClick={onClick}
            title={path}
        >
            <div className="thumbnail-img-wrapper">
                <button
                    className="thumbnail-remove-btn"
                    onClick={onRemove}
                    title="Remove Image"
                >
                    ×
                </button>
                {loading ? (
                    <div className="thumbnail-loading">...</div>
                ) : src ? (
                    <img src={src} alt={filename} />
                ) : (
                    <div className="thumbnail-error">?</div>
                )}
            </div>
            <div className="thumbnail-name">{filename}</div>
        </div>
    );
}
