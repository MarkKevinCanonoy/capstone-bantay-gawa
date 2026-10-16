import React from 'react';
import { useApp } from '../context/AppContext';
import { NavigationTab } from '../types';
import { Home, Fingerprint, MapPin, ClipboardList, User } from 'lucide-react';

export const BottomNav: React.FC = () => {
  const { currentTab, setCurrentTab } = useApp();

  const tabs: { id: NavigationTab; label: string; icon: React.ReactNode }[] = [
    { id: 'home', label: 'Home', icon: <Home className="w-5 h-5" /> },
    { id: 'attendance', label: 'Attendance', icon: <Fingerprint className="w-5 h-5" /> },
    { id: 'map', label: 'Map', icon: <MapPin className="w-5 h-5" /> },
    { id: 'reports', label: 'Reports', icon: <ClipboardList className="w-5 h-5" /> },
    { id: 'profile', label: 'Profile', icon: <User className="w-5 h-5" /> },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-[#ffffff] border-t border-[#c4c6cf] pb-safe h-16 flex justify-around items-center px-2">
      {tabs.map((tab) => {
        const isActive = currentTab === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => setCurrentTab(tab.id)}
            className={`flex flex-col items-center justify-center py-1.5 px-3 rounded-lg transition-all active:scale-95 min-w-[64px] ${
              isActive
                ? 'bg-[#1a365d] text-white shadow-sm'
                : 'text-[#43474e] hover:bg-[#e9e7eb]'
            }`}
          >
            {tab.icon}
            <span className={`text-[11px] font-semibold mt-0.5 ${isActive ? 'text-white' : 'text-[#43474e]'}`}>
              {tab.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
};
