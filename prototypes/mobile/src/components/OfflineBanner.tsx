import React from 'react';
import { useApp } from '../context/AppContext';
import { AlertTriangle, RefreshCw } from 'lucide-react';

export const OfflineBanner: React.FC = () => {
  const { isOffline, pendingSyncCount, syncData } = useApp();

  if (!isOffline && pendingSyncCount === 0) return null;

  return (
    <div className="fixed top-[48px] left-0 right-0 z-40 bg-[#c2410c] text-white px-4 py-2 flex items-center justify-between shadow-sm text-xs transition-all">
      <div className="flex items-center gap-2">
        <AlertTriangle className="w-4 h-4 shrink-0 animate-pulse" />
        <span className="font-semibold">
          {isOffline ? 'Offline Mode Active' : 'Pending Sync Queue'}
        </span>
        <span className="text-white/80 hidden sm:inline">
          • Records saved locally until reconnected
        </span>
      </div>

      <div className="flex items-center gap-2">
        {pendingSyncCount > 0 && (
          <span className="bg-black/20 px-2 py-0.5 rounded text-[11px] font-mono">
            {pendingSyncCount} queued
          </span>
        )}
        <button
          onClick={syncData}
          className="bg-white text-[#c2410c] font-semibold px-2.5 py-1 rounded text-[11px] hover:bg-white/90 active:scale-95 transition-all flex items-center gap-1"
        >
          <RefreshCw className="w-3 h-3" />
          <span>Sync Now</span>
        </button>
      </div>
    </div>
  );
};
