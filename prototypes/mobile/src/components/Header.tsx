import React from 'react';
import { useApp } from '../context/AppContext';
import { CloudOff, Wifi, RefreshCw, LogOut } from 'lucide-react';

export const Header: React.FC = () => {
  const { isOffline, setIsOffline, pendingSyncCount, syncData, profile, logout } = useApp();

  return (
    <header className="fixed top-0 left-0 right-0 z-50 bg-[#faf9fd] border-b border-[#c4c6cf] h-[52px] px-4 flex items-center justify-between transition-colors shadow-xs">
      <div className="flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-full bg-[#1a365d] flex items-center justify-center text-[#86a0cd] font-bold text-xs shadow-sm ring-1 ring-black/5 shrink-0">
          LGU
        </div>
        <div className="flex flex-col">
          <h1 className="font-bold text-base text-[#002045] leading-none tracking-tight">
            BantayGawa
          </h1>
        </div>
      </div>

      <div className="flex items-center gap-2">
        {pendingSyncCount > 0 && !isOffline && (
          <button
            onClick={syncData}
            className="flex items-center gap-1 bg-[#166534]/10 text-[#166534] text-xs px-2.5 py-1 rounded-full font-medium hover:bg-[#166534]/20 transition-colors"
            title="Sync pending offline logs"
          >
            <RefreshCw className="w-3 h-3 animate-spin" />
            <span>Sync ({pendingSyncCount})</span>
          </button>
        )}

        <button
          onClick={() => setIsOffline(!isOffline)}
          className={`w-8 h-8 flex items-center justify-center rounded-full transition-all active:scale-95 ${
            isOffline
              ? 'bg-[#c2410c] text-white shadow-sm'
              : 'text-[#43474e] hover:bg-[#efedf1]'
          }`}
          title={isOffline ? 'Offline Mode Active (Click to go Online)' : 'Online Mode (Click to test Offline Mode)'}
        >
          {isOffline ? <CloudOff className="w-4 h-4" /> : <Wifi className="w-4 h-4" />}
        </button>

        {/* Current Worker Avatar badge + quick Logout button */}
        <div className="flex items-center gap-1.5 pl-1 border-l border-[#c4c6cf]/60">
          <img
            src={profile.photoUrl}
            alt={profile.name}
            className="w-7 h-7 rounded-full object-cover border border-[#002045]"
            title={`Logged in as ${profile.name}`}
          />
          <button
            onClick={logout}
            className="w-8 h-8 flex items-center justify-center rounded-full text-[#991b1b] hover:bg-[#ffdad6]/50 transition-all"
            title="Switch Worker / Log Out"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
