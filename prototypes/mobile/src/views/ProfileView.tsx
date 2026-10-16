import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  ShieldCheck,
  MapPin,
  Clock,
  Star,
  ThumbsUp,
  LogOut,
  RefreshCw,
  Award,
  Globe
} from 'lucide-react';

export const ProfileView: React.FC = () => {
  const {
    profile,
    performanceLogs,
    attendanceLogs,
    accomplishmentReports,
    syncData,
    pendingSyncCount,
    logout,
    language,
    setLanguage
  } = useApp();

  const [activeTab, setActiveTab] = useState<'attendance' | 'accomplishments'>('attendance');
  const [showLogoutModal, setShowLogoutModal] = useState<boolean>(false);

  return (
    <div className="flex flex-col gap-4 pb-24 max-w-md mx-auto w-full">
      {/* Title */}
      <div className="pt-2">
        <h2 className="text-xl font-bold text-[#002045]">Worker Profile</h2>
      </div>

      {/* Profile Header Card */}
      <section className="bg-white border border-[#c4c6cf] rounded-2xl p-5 shadow-sm flex flex-col items-center text-center">
        <div className="relative w-24 h-24 mb-3">
          <img
            src={profile.photoUrl}
            alt={profile.name}
            className="w-full h-full rounded-full object-cover border-4 border-[#faf9fd] shadow-md"
          />
          <div className="absolute bottom-0 right-0 bg-[#166534] text-white p-1 rounded-full border-2 border-white shadow-sm">
            <ShieldCheck className="w-4 h-4" />
          </div>
        </div>

        <h3 className="font-bold text-lg text-[#002045]">{profile.name}</h3>
        <p className="text-xs font-mono font-semibold text-[#5c5e63]">ID: {profile.workerId}</p>

        <div className="flex gap-2 mt-3 flex-wrap justify-center">
          <span className="bg-[#f4f3f7] text-[#43474e] text-xs font-semibold px-3 py-1 rounded-full border border-[#c4c6cf] flex items-center gap-1">
            <MapPin className="w-3.5 h-3.5 text-[#002045]" />
            <span>{profile.assignedArea}</span>
          </span>
          <span className="bg-[#f4f3f7] text-[#43474e] text-xs font-semibold px-3 py-1 rounded-full border border-[#c4c6cf] flex items-center gap-1">
            <Clock className="w-3.5 h-3.5 text-[#002045]" />
            <span>{profile.shiftTime}</span>
          </span>
        </div>
      </section>

      {/* Performance Credit Widget */}
      <section className="bg-[#f4f3f7] border border-[#c4c6cf] rounded-2xl p-4 shadow-sm flex flex-col gap-3">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Award className="w-5 h-5 text-[#854d0e]" />
            <h3 className="font-bold text-base text-[#002045]">Performance Credit</h3>
          </div>
          <span className="font-black text-xl text-[#002045]">
            {profile.performanceScore}
            <span className="text-xs text-[#5c5e63] font-normal">/10</span>
          </span>
        </div>

        {/* 10 Stars row */}
        <div className="flex gap-1 justify-center py-1 bg-white rounded-xl border border-[#c4c6cf]/60">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((num) => (
            <Star
              key={num}
              className={`w-5 h-5 ${
                num <= Math.floor(profile.performanceScore)
                  ? 'text-[#eab308] fill-[#eab308]'
                  : num === Math.ceil(profile.performanceScore) && profile.performanceScore % 1 !== 0
                  ? 'text-[#eab308] fill-[#eab308]/50'
                  : 'text-[#c4c6cf] fill-none'
              }`}
            />
          ))}
        </div>

        {/* Recent credit/penalty logs */}
        <div className="flex flex-col gap-2 mt-1">
          <h4 className="text-[11px] font-bold text-[#5c5e63] uppercase tracking-wider">
            Recent Rating Logs
          </h4>

          {performanceLogs.map((log) => (
            <div
              key={log.id}
              className="flex items-center justify-between bg-white p-3 rounded-xl border border-[#c4c6cf] text-xs"
            >
              <div className="flex items-center gap-2.5">
                <div
                  className={`p-2 rounded-full ${
                    log.type === 'credit'
                      ? 'bg-[#166534]/15 text-[#166534]'
                      : 'bg-[#854d0e]/15 text-[#854d0e]'
                  }`}
                >
                  <ThumbsUp className="w-4 h-4" />
                </div>
                <div>
                  <p className="font-bold text-[#1a1c1e]">{log.title}</p>
                  <p className="text-[10px] font-mono text-[#5c5e63]">{log.timestamp}</p>
                </div>
              </div>

              <span
                className={`font-mono font-bold text-xs px-2 py-0.5 rounded ${
                  log.points > 0 ? 'bg-[#166534]/10 text-[#166534]' : 'bg-[#991b1b]/10 text-[#991b1b]'
                }`}
              >
                {log.points > 0 ? `+${log.points}` : log.points} pts
              </span>
            </div>
          ))}
        </div>
      </section>

      {/* History Tabs */}
      <section className="bg-white border border-[#c4c6cf] rounded-2xl overflow-hidden shadow-sm">
        <div className="flex border-b border-[#c4c6cf]">
          <button
            onClick={() => setActiveTab('attendance')}
            className={`flex-1 py-3 text-xs font-bold text-center transition-colors ${
              activeTab === 'attendance'
                ? 'text-[#002045] border-b-2 border-[#002045] bg-[#f4f3f7]'
                : 'text-[#5c5e63] hover:bg-[#f4f3f7]'
            }`}
          >
            Attendance Logs
          </button>
          <button
            onClick={() => setActiveTab('accomplishments')}
            className={`flex-1 py-3 text-xs font-bold text-center transition-colors ${
              activeTab === 'accomplishments'
                ? 'text-[#002045] border-b-2 border-[#002045] bg-[#f4f3f7]'
                : 'text-[#5c5e63] hover:bg-[#f4f3f7]'
            }`}
          >
            Accomplishments
          </button>
        </div>

        <div className="p-3 divide-y divide-[#c4c6cf]/50">
          {activeTab === 'attendance' ? (
            attendanceLogs.slice(0, 5).map((log) => (
              <div key={log.id} className="py-2.5 flex items-center justify-between text-xs">
                <div>
                  <p className="font-bold text-[#1a1c1e]">{log.action} - {log.zone}</p>
                  <p className="text-[10px] font-mono text-[#5c5e63]">{log.timeFormatted}</p>
                </div>
                <span className="bg-[#166534]/10 text-[#166534] font-bold text-[10px] px-2 py-0.5 rounded">
                  {log.status}
                </span>
              </div>
            ))
          ) : (
            accomplishmentReports.slice(0, 5).map((rep) => (
              <div key={rep.id} className="py-2.5 flex items-center justify-between text-xs">
                <div>
                  <p className="font-bold text-[#1a1c1e]">{rep.title}</p>
                  <p className="text-[10px] font-mono text-[#5c5e63]">{rep.date}</p>
                </div>
                <span
                  className={`font-bold text-[10px] px-2 py-0.5 rounded ${
                    rep.status === 'Approved'
                      ? 'bg-[#166534]/10 text-[#166534]'
                      : rep.status === 'Pending'
                      ? 'bg-[#854d0e]/10 text-[#854d0e]'
                      : 'bg-[#991b1b]/10 text-[#991b1b]'
                  }`}
                >
                  {rep.status}
                </span>
              </div>
            ))
          )}
        </div>
      </section>

      {/* Language Selector */}
      <section className="bg-white border border-[#c4c6cf] rounded-2xl p-4 shadow-sm flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-[#002045]/10 text-[#002045] rounded-xl">
            <Globe className="w-5 h-5" />
          </div>
          <div>
            <h4 className="font-extrabold text-sm text-[#002045]">
              {language === 'ph' ? 'Wika / Language' : 'App Language'}
            </h4>
            <p className="text-xs text-[#5c5e63]">
              {language === 'ph' ? 'Pumili ng wika para sa app' : 'Select preferred language'}
            </p>
          </div>
        </div>

        <div className="flex bg-[#f4f3f7] p-1 rounded-xl border border-[#c4c6cf]">
          <button
            onClick={() => setLanguage('ph')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
              language === 'ph'
                ? 'bg-[#002045] text-white shadow-xs'
                : 'text-[#43474e] hover:text-[#002045]'
            }`}
          >
            Tagalog
          </button>
          <button
            onClick={() => setLanguage('en')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
              language === 'en'
                ? 'bg-[#002045] text-white shadow-xs'
                : 'text-[#43474e] hover:text-[#002045]'
            }`}
          >
            English
          </button>
        </div>
      </section>

      {/* Account Settings Actions */}
      <section className="flex flex-col gap-2.5 mt-2">
        <button
          onClick={syncData}
          className="w-full h-11 bg-white border border-[#c4c6cf] text-[#002045] font-bold text-xs rounded-xl flex items-center justify-center gap-2 hover:bg-[#f4f3f7] active:scale-[0.98] transition-all"
        >
          <RefreshCw className="w-4 h-4 text-[#002045]" />
          <span>Sync Data Queue ({pendingSyncCount} Items)</span>
        </button>

        <button
          onClick={() => setShowLogoutModal(true)}
          className="w-full h-11 bg-[#991b1b] text-white font-bold text-xs rounded-xl flex items-center justify-center gap-2 hover:bg-[#991b1b]/90 active:scale-[0.98] transition-all shadow-sm"
        >
          <LogOut className="w-4 h-4" />
          <span>Log Out</span>
        </button>
      </section>

      {/* Logout Confirmation Modal */}
      {showLogoutModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white border border-[#c4c6cf] rounded-2xl max-w-sm w-full p-5 flex flex-col gap-4 shadow-xl text-center">
            <div className="w-12 h-12 rounded-full bg-[#ffdad6] text-[#93000a] flex items-center justify-center mx-auto">
              <LogOut className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-base text-[#002045]">Log Out of BantayGawa?</h3>
              <p className="text-xs text-[#43474e] mt-1">
                Any unsynced attendance or field reports will remain queued in local storage until you sign back in.
              </p>
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => setShowLogoutModal(false)}
                className="flex-1 py-2.5 border border-[#c4c6cf] rounded-xl font-semibold text-xs text-[#43474e] hover:bg-[#f4f3f7]"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  setShowLogoutModal(false);
                  logout();
                }}
                className="flex-1 py-2.5 bg-[#991b1b] text-white rounded-xl font-bold text-xs hover:bg-[#991b1b]/90"
              >
                Confirm Log Out
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
