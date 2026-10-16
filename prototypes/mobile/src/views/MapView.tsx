import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  MapPin,
  CheckCircle2,
  AlertTriangle,
  Compass,
  Users
} from 'lucide-react';

export const MapView: React.FC = () => {
  const {
    currentZone,
    isInsideGeofence,
    profile
  } = useApp();

  const [showTeamMembers, setShowTeamMembers] = useState<boolean>(true);

  const activeZone = currentZone;

  return (
    <div className="flex flex-col gap-4 pb-24 max-w-md mx-auto w-full">
      {/* Title & Geofence Header */}
      <div className="flex justify-between items-center pt-2">
        <div>
          <h2 className="text-xl font-bold text-[#002045]">Geofence Map</h2>
        </div>
      </div>

      {/* Geofence Alert Banner */}
      <div
        className={`px-3 py-2 rounded-xl border flex items-center justify-between text-xs transition-colors ${
          isInsideGeofence
            ? 'bg-[#166534]/10 border-[#166534]/30 text-[#166534]'
            : 'bg-[#c2410c]/10 border-[#c2410c]/30 text-[#c2410c] animate-pulse'
        }`}
      >
        <div className="flex items-center gap-2 font-bold">
          {isInsideGeofence ? (
            <CheckCircle2 className="w-4 h-4" />
          ) : (
            <AlertTriangle className="w-4 h-4" />
          )}
          <span>{isInsideGeofence ? 'INSIDE AUTHORIZED GEOFENCE' : 'WARNING: OUTSIDE ASSIGNED GEOFENCE'}</span>
        </div>
      </div>

      {/* Interactive Map Visualizer Container */}
      <div
        className="relative w-full aspect-4/5 rounded-2xl overflow-hidden border-2 border-[#74777f] shadow-sm flex flex-col justify-between bg-[#f4f3f7]"
      >
        {/* Background Pattern / Map simulation */}
        <div className="absolute inset-0 opacity-20 pointer-events-none">
          <div
            className="w-full h-full"
            style={{
              backgroundImage:
                'linear-gradient(to right, #002045 1px, transparent 1px), linear-gradient(to bottom, #002045 1px, transparent 1px)',
              backgroundSize: '24px 24px'
            }}
          />
        </div>

        {/* Geofence Perimeter Box SVG */}
        <svg className="absolute inset-0 w-full h-full pointer-events-none p-8">
          <rect
            x="10%"
            y="10%"
            width="80%"
            height="80%"
            rx="16"
            fill={isInsideGeofence ? 'rgba(0, 32, 69, 0.08)' : 'rgba(194, 65, 12, 0.08)'}
            stroke={isInsideGeofence ? '#002045' : '#c2410c'}
            strokeWidth="2"
            strokeDasharray="6,4"
          />
        </svg>

        {/* Map Top Floating Controls */}
        <div className="relative z-10 p-3 flex justify-between items-center">
          <div className="bg-white/90 backdrop-blur-md px-3 py-1.5 rounded-full border border-[#c4c6cf] shadow-sm flex items-center gap-2">
            <Compass className="w-4 h-4 text-[#002045] animate-spin" style={{ animationDuration: '10s' }} />
            <span className="font-bold text-xs text-[#002045]">{activeZone.name}</span>
          </div>

          <button
            onClick={() => setShowTeamMembers(!showTeamMembers)}
            className={`p-2 rounded-full border shadow-sm transition-all ${
              showTeamMembers ? 'bg-[#002045] text-white border-[#002045]' : 'bg-white text-[#5c5e63] border-[#c4c6cf]'
            }`}
            title="Toggle Team Pins"
          >
            <Users className="w-4 h-4" />
          </button>
        </div>

        {/* Center Worker Location Marker */}
        <div className="relative z-10 flex-1 flex items-center justify-center p-4">
          <div className="relative flex flex-col items-center">
            {/* Accuracy Pulsing Circle */}
            <div className={`absolute w-24 h-24 rounded-full animate-ping ${
              isInsideGeofence ? 'bg-[#002045]/15' : 'bg-[#c2410c]/20'
            }`} />

            {/* Worker Pin Tag */}
            <div className="z-10 bg-[#002045] text-white text-[11px] font-bold px-2.5 py-1 rounded-full shadow-md border border-white flex items-center gap-1.5 mb-1">
              <span className="w-2 h-2 rounded-full bg-[#86a0cd]" />
              <span>Worker {profile.workerId} (You)</span>
            </div>

            {/* Center Location Pulse Dot */}
            <div className="w-6 h-6 rounded-full bg-[#002045] ring-4 ring-[#adc7f7] shadow-lg flex items-center justify-center text-white">
              <MapPin className="w-3.5 h-3.5 fill-white" />
            </div>
          </div>

          {/* Team Member Pins */}
          {showTeamMembers && (
            <>
              <div className="absolute top-1/4 left-1/4 flex flex-col items-center">
                <div className="bg-white text-[#002045] text-[9px] font-bold px-1.5 py-0.5 rounded shadow border border-[#c4c6cf]">
                  Maria S.
                </div>
                <div className="w-4 h-4 rounded-full bg-[#166534] ring-2 ring-white shadow-sm" />
              </div>

              <div className="absolute bottom-1/3 right-1/4 flex flex-col items-center">
                <div className="bg-white text-[#002045] text-[9px] font-bold px-1.5 py-0.5 rounded shadow border border-[#c4c6cf]">
                  Pedro R.
                </div>
                <div className="w-4 h-4 rounded-full bg-[#166534] ring-2 ring-white shadow-sm" />
              </div>
            </>
          )}
        </div>

        {/* Map Bottom Information Drawer */}
        <div className="relative z-10 bg-white/95 backdrop-blur-md p-3.5 border-t border-[#c4c6cf] rounded-b-2xl flex flex-col gap-2 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-bold text-sm text-[#002045]">{activeZone.name}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
