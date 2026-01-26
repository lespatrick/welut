import { useState, useEffect } from 'react';

interface LutItem {
    id: string;
    name: string;
    path: string;
}

interface LutLibraryProps {
    onSelect: (lut: LutItem | null) => void;
    selectedLutId: string | null;
}


// Simple icons
const CubeIcon = () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
        <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
        <line x1="12" y1="22.08" x2="12" y2="12"></line>
    </svg>
);

const ChevronIcon = ({ expanded }: { expanded: boolean }) => (
    <svg
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        style={{ transform: expanded ? 'rotate(90deg)' : 'rotate(0deg)', transition: 'transform 0.2s' }}
    >
        <polyline points="9 18 15 12 9 6"></polyline>
    </svg>
);

export function LutLibrary({ onSelect, selectedLutId }: LutLibraryProps) {
    const [luts, setLuts] = useState<LutItem[]>([]);
    const [importing, setImporting] = useState(false);
    const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());

    useEffect(() => {
        loadLuts();
    }, []);

    const loadLuts = async () => {
        const list = await window.ipcRenderer.invoke('lut:get-all');
        setLuts(list);
    };

    const handleImport = async () => {
        setImporting(true);
        try {
            const newItem = await window.ipcRenderer.invoke('lut:import');
            if (newItem) {
                loadLuts();
            }
        } finally {
            setImporting(false);
        }
    };

    const handleDelete = async (e: React.MouseEvent, id: string) => {
        e.stopPropagation();
        if (confirm('Are you sure you want to delete this LUT?')) {
            const success = await window.ipcRenderer.invoke('lut:delete', id);
            if (success) {
                if (selectedLutId === id) {
                    onSelect(null);
                }
                loadLuts();
            }
        }
    };

    const toggleGroup = (groupName: string) => {
        const next = new Set(expandedGroups);
        if (next.has(groupName)) {
            next.delete(groupName);
        } else {
            next.add(groupName);
        }
        setExpandedGroups(next);
    };

    // Grouping logic
    const groups: Record<string, LutItem[]> = {};
    luts.forEach(lut => {
        const parts = lut.name.split('/');
        const groupName = parts.length > 1 ? parts[0] : 'Imported';
        const displayName = parts.length > 1 ? parts.slice(1).join('/') : lut.name;

        if (!groups[groupName]) groups[groupName] = [];
        groups[groupName].push({ ...lut, name: displayName });
    });

    const sortedGroups = Object.keys(groups).sort((a, b) => {
        if (a === 'Imported') return 1;
        if (b === 'Imported') return -1;
        return a.localeCompare(b);
    });

    return (
        <div className="card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
            <div className="lut-header">
                <h2>Library</h2>
                <button
                    onClick={handleImport}
                    disabled={importing}
                    className="import-btn"
                >
                    {importing ? '...' : '+'}
                </button>
            </div>

            <div className="lut-list">
                {luts.length === 0 && <div className="empty-state">No LUTs imported.</div>}

                {sortedGroups.map(groupName => {
                    const isExpanded = expandedGroups.has(groupName);
                    return (
                        <div key={groupName} className="lut-group">
                            <div
                                className="lut-group-header"
                                onClick={() => toggleGroup(groupName)}
                            >
                                <ChevronIcon expanded={isExpanded} />
                                <span>{groupName}</span>
                                <span className="group-count">{groups[groupName].length}</span>
                            </div>

                            {isExpanded && (
                                <div className="lut-group-content">
                                    {groups[groupName].map(lut => (
                                        <div
                                            key={lut.id}
                                            className={`lut-item ${selectedLutId === lut.id ? 'selected' : ''}`}
                                            onClick={() => onSelect(lut)}
                                        >
                                            <div className="lut-icon">
                                                <CubeIcon />
                                            </div>
                                            <span className="lut-name" title={lut.path}>{lut.name}</span>
                                            <button
                                                className="delete-btn"
                                                onClick={(e) => handleDelete(e, lut.id)}
                                                title="Delete LUT"
                                            >
                                                ×
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
