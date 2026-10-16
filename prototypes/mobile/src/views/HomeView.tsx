import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  MapPin,
  Clock,
  CheckCircle2,
  LogIn,
  Coffee,
  LogOut,
  Upload,
  Calendar,
  AlertOctagon,
  Megaphone,
  ShieldCheck,
  ChevronRight,
  Lock,
  Sparkles,
  ArrowRight
} from 'lucide-react';
import { AnnouncementsModal } from '../components/AnnouncementsModal';

export const HomeView: React.FC = () => {
  const {
    setCurrentTab,
    profile,
    currentZone,
    isInsideGeofence,
    attendanceLogs,
    announcements,
    setShowLeaveModal,
    setShowIssueReportModal,
    language
  } = useApp();

  const [showAnnouncementsModal, setShowAnnouncementsModal] = useState<boolean>(false);

  // Find today's attendance logs
  const todayDateStr = new Date().toDateString();
  const todayLogs = attendanceLogs.filter((l) => {
    try {
      return new Date(l.timestamp).toDateString() === todayDateStr;
    } catch {
      return false;
    }
  });

  const latestTimeIn = todayLogs.find((l) => l.action === 'Time-In');
  const latestBreakOut = todayLogs.find((l) => l.action === 'Break-Out');
  const latestBreakIn = todayLogs.find((l) => l.action === 'Break-In');
  const latestTimeOut = todayLogs.find((l) => l.action === 'Time-Out');

  // Determine current overall attendance state
  let overallStatusText = language === 'ph' ? 'HINDI PA NAKAPASOK' : 'NOT CLOCKED IN';
  let overallStatusColor = 'bg-[#991b1b]/10 text-[#991b1b] border-[#991b1b]/30';

  if (latestTimeOut) {
    overallStatusText = language === 'ph' ? 'TAPOS NA ANG SHIFT' : 'SHIFT COMPLETED';
    overallStatusColor = 'bg-[#1a365d]/10 text-[#002045] border-[#002045]/30';
  } else if (latestBreakOut && !latestBreakIn) {
    overallStatusText = language === 'ph' ? 'NASA LUNCH BREAK' : 'ON LUNCH BREAK';
    overallStatusColor = 'bg-[#854d0e]/10 text-[#854d0e] border-[#854d0e]/30';
  } else if (latestTimeIn) {
    overallStatusText = language === 'ph' ? 'NAKA-TIME IN / NASA TRABAHO' : 'CLOCKED IN / ON DUTY';
    overallStatusColor = 'bg-[#166534]/10 text-[#166534] border-[#166534]/30';
  }

  // Determine active dynamic step (0 = Time In, 1 = Break Out, 2 = Break In, 3 = Time Out, 4 = All Done)
  let activeStepIndex = 0;
  if (latestTimeOut) {
    activeStepIndex = 4;
  } else if (latestBreakIn) {
    activeStepIndex = 3; // Next is Time Out
  } else if (latestBreakOut) {
    activeStepIndex = 2; // Next is Break In
  } else if (latestTimeIn) {
    activeStepIndex = 1; // Next is Break Out (or Time Out)
  }

  const urgentAnnouncementsCount = announcements.filter((a) => a.priority === 'high').length;

  return (
    <div className="flex flex-col gap-5 pb-24 max-w-md mx-auto w-full">
      {/* Top Header Worker Badge */}
      <div className="flex items-center justify-between pt-2">
        <div>
          <h2 className="text-xl sm:text-2xl font-black text-[#002045]">
            {language === 'ph' ? 'Kamusta,' : 'Welcome,'} {profile.name.split(' ')[0]}
          </h2>
          <p className="text-xs text-[#43474e] font-semibold">
            ID: {profile.workerId}
          </p>
        </div>
      </div>

      {/* 1. STATUS OVERVIEW CARD */}
      <section className="bg-white border-2 border-[#002045] rounded-3xl p-5 shadow-lg flex flex-col gap-4">
        {/* Top Shift & Geofence Banner */}
        <div className="flex flex-col gap-2 border-b border-[#c4c6cf]/60 pb-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-[#43474e]">
              {language === 'ph' ? 'KASALUKUYANG ESTADO' : 'WORKER STATUS'}
            </span>
          </div>

          {/* Assigned Area & Shift Time */}
          <div className="bg-[#f4f3f7] rounded-2xl p-3.5 border border-[#c4c6cf]/60 flex flex-col gap-2 mt-1">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-[#002045] text-white flex items-center justify-center shrink-0">
                  <MapPin className="w-5 h-5 text-emerald-400" />
                </div>
                <div>
                  <p className="font-extrabold text-sm text-[#002045]">{currentZone.name}</p>
                </div>
              </div>

              {/* Geofence Status Badge */}
              <div
                className={`px-2.5 py-1 rounded-xl text-[11px] font-extrabold flex items-center gap-1 ${
                  isInsideGeofence
                    ? 'bg-[#166534]/15 text-[#166534] border border-[#166534]/30'
                    : 'bg-[#c2410c]/15 text-[#c2410c] border border-[#c2410c]/30'
                }`}
              >
                <span className={`w-2 h-2 rounded-full ${isInsideGeofence ? 'bg-[#166534]' : 'bg-[#c2410c]'}`} />
                <span>{isInsideGeofence ? (language === 'ph' ? 'Nasa Zone' : 'In Geofence') : (language === 'ph' ? 'Labas sa Zone' : 'Out of Bounds')}</span>
              </div>
            </div>

            <div className="h-px bg-[#c4c6cf]/40 my-0.5" />

            <div className="flex items-center justify-between text-xs text-[#002045] font-bold">
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-[#002045]" />
                <span>{profile.shift}: {profile.shiftTime}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Dynamic Time/Schedule Attendance Indicators */}
        <div className="flex flex-col gap-2.5">
          <div className="flex items-center justify-between">
            <h4 className="font-extrabold text-xs text-[#002045] uppercase tracking-wider">
              {language === 'ph' ? 'Iskedyul sa Pagtatrabaho Ngayon' : 'Today\'s Shift Schedule & Progress'}
            </h4>
            <span className="text-[11px] font-bold text-[#1a365d] bg-[#f4f3f7] px-2 py-0.5 rounded-md border border-[#c4c6cf]">
              {profile.shift} ({profile.shiftTime})
            </span>
          </div>

          {/* Schedule Helper Times derived from Shift */}
          {(() => {
            const sched = (() => {
              const st = profile.shiftTime || '';
              if (st.includes('06:00 AM') || st.includes('06:00')) {
                return { in: '06:00 AM', bOut: '10:00 AM', bIn: '11:00 AM', out: '02:00 PM' };
              } else if (st.includes('07:00 AM') || st.includes('07:00')) {
                return { in: '07:00 AM', bOut: '11:00 AM', bIn: '12:00 PM', out: '03:00 PM' };
              } else if (st.includes('02:00 PM')) {
                return { in: '02:00 PM', bOut: '06:00 PM', bIn: '07:00 PM', out: '10:00 PM' };
              }
              return { in: '08:00 AM', bOut: '12:00 PM', bIn: '01:00 PM', out: '05:00 PM' };
            })();

            return (
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {/* Step 1: TIME IN */}
                <div
                  className={`p-3 rounded-2xl border flex flex-col items-center text-center transition-all ${
                    latestTimeIn
                      ? 'bg-emerald-50 border-emerald-500/60 text-[#166534] shadow-xs'
                      : 'bg-gray-100/90 border-gray-300 text-gray-400 opacity-65'
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center mb-1 ${
                      latestTimeIn
                        ? 'bg-[#166534] text-white shadow-xs'
                        : 'bg-gray-200 text-gray-400'
                    }`}
                  >
                    {latestTimeIn ? <CheckCircle2 className="w-6 h-6 stroke-[2.5]" /> : <LogIn className="w-5 h-5 text-gray-400" />}
                  </div>
                  <span className={`font-extrabold text-xs ${latestTimeIn ? 'text-[#002045]' : 'text-gray-500'}`}>Time In</span>
                  <span className={`text-[11px] font-mono font-bold mt-0.5 ${latestTimeIn ? 'text-[#166534]' : 'text-gray-400'}`}>
                    {latestTimeIn ? latestTimeIn.timeFormatted : '--:--'}
                  </span>
                  <span className={`text-[9px] font-bold mt-1 px-1.5 py-0.5 rounded-full uppercase ${
                    latestTimeIn ? 'bg-[#166534]/15 text-[#166534]' : 'bg-gray-200 text-gray-500'
                  }`}>
                    {latestTimeIn ? (language === 'ph' ? 'TAPOS NA' : 'LOGGED') : (language === 'ph' ? 'HINDI PA' : 'NOT DONE')}
                  </span>
                </div>

                {/* Step 2: BREAK OUT */}
                <div
                  className={`p-3 rounded-2xl border flex flex-col items-center text-center transition-all ${
                    latestBreakOut
                      ? 'bg-amber-50 border-amber-500/60 text-[#854d0e] shadow-xs'
                      : 'bg-gray-100/90 border-gray-300 text-gray-400 opacity-65'
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center mb-1 ${
                      latestBreakOut
                        ? 'bg-[#854d0e] text-white shadow-xs'
                        : 'bg-gray-200 text-gray-400'
                    }`}
                  >
                    {latestBreakOut ? <CheckCircle2 className="w-6 h-6 stroke-[2.5]" /> : <Coffee className="w-5 h-5 text-gray-400" />}
                  </div>
                  <span className={`font-extrabold text-xs ${latestBreakOut ? 'text-[#002045]' : 'text-gray-500'}`}>Break Out</span>
                  <span className={`text-[11px] font-mono font-bold mt-0.5 ${latestBreakOut ? 'text-[#854d0e]' : 'text-gray-400'}`}>
                    {latestBreakOut ? latestBreakOut.timeFormatted : '--:--'}
                  </span>
                  <span className={`text-[9px] font-bold mt-1 px-1.5 py-0.5 rounded-full uppercase ${
                    latestBreakOut ? 'bg-amber-500/20 text-[#854d0e]' : 'bg-gray-200 text-gray-500'
                  }`}>
                    {latestBreakOut ? (language === 'ph' ? 'TAPOS NA' : 'LOGGED') : (language === 'ph' ? 'HINDI PA' : 'NOT DONE')}
                  </span>
                </div>

                {/* Step 3: BREAK IN */}
                <div
                  className={`p-3 rounded-2xl border flex flex-col items-center text-center transition-all ${
                    latestBreakIn
                      ? 'bg-blue-50 border-blue-500/60 text-[#1a365d] shadow-xs'
                      : 'bg-gray-100/90 border-gray-300 text-gray-400 opacity-65'
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center mb-1 ${
                      latestBreakIn
                        ? 'bg-[#1a365d] text-white shadow-xs'
                        : 'bg-gray-200 text-gray-400'
                    }`}
                  >
                    {latestBreakIn ? <CheckCircle2 className="w-6 h-6 stroke-[2.5]" /> : <LogIn className="w-5 h-5 text-gray-400" />}
                  </div>
                  <span className={`font-extrabold text-xs ${latestBreakIn ? 'text-[#002045]' : 'text-gray-500'}`}>Break In</span>
                  <span className={`text-[11px] font-mono font-bold mt-0.5 ${latestBreakIn ? 'text-[#1a365d]' : 'text-gray-400'}`}>
                    {latestBreakIn ? latestBreakIn.timeFormatted : '--:--'}
                  </span>
                  <span className={`text-[9px] font-bold mt-1 px-1.5 py-0.5 rounded-full uppercase ${
                    latestBreakIn ? 'bg-blue-500/20 text-[#1a365d]' : 'bg-gray-200 text-gray-500'
                  }`}>
                    {latestBreakIn ? (language === 'ph' ? 'TAPOS NA' : 'LOGGED') : (language === 'ph' ? 'HINDI PA' : 'NOT DONE')}
                  </span>
                </div>

                {/* Step 4: TIME OUT */}
                <div
                  className={`p-3 rounded-2xl border flex flex-col items-center text-center transition-all ${
                    latestTimeOut
                      ? 'bg-red-50 border-red-500/60 text-[#991b1b] shadow-xs'
                      : 'bg-gray-100/90 border-gray-300 text-gray-400 opacity-65'
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center mb-1 ${
                      latestTimeOut
                        ? 'bg-[#991b1b] text-white shadow-xs'
                        : 'bg-gray-200 text-gray-400'
                    }`}
                  >
                    {latestTimeOut ? <CheckCircle2 className="w-6 h-6 stroke-[2.5]" /> : <LogOut className="w-5 h-5 text-gray-400" />}
                  </div>
                  <span className={`font-extrabold text-xs ${latestTimeOut ? 'text-[#002045]' : 'text-gray-500'}`}>Time Out</span>
                  <span className={`text-[11px] font-mono font-bold mt-0.5 ${latestTimeOut ? 'text-[#991b1b]' : 'text-gray-400'}`}>
                    {latestTimeOut ? latestTimeOut.timeFormatted : '--:--'}
                  </span>
                  <span className={`text-[9px] font-bold mt-1 px-1.5 py-0.5 rounded-full uppercase ${
                    latestTimeOut ? 'bg-red-500/20 text-[#991b1b]' : 'bg-gray-200 text-gray-500'
                  }`}>
                    {latestTimeOut ? (language === 'ph' ? 'TAPOS NA' : 'LOGGED') : (language === 'ph' ? 'HINDI PA' : 'NOT DONE')}
                  </span>
                </div>
              </div>
            );
          })()}
        </div>
      </section>

      {/* 2. LARGE SHORTCUT BUTTONS SECTION */}
      <section className="flex flex-col gap-3">
        <h3 className="font-black text-sm text-[#002045] uppercase tracking-wider px-1">
          {language === 'ph' ? 'Mga Pangunahing Aksyon' : 'Quick Actions'}
        </h3>

        {/* GRID OF 4 LARGE ACCESSIBLE SHORTCUT BUTTONS */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {/* Button 1: LOG ATTENDANCE */}
          <button
            onClick={() => setCurrentTab('attendance')}
            className="w-full h-20 bg-[#002045] hover:bg-[#1a365d] active:scale-[0.98] text-white rounded-3xl p-4 shadow-lg border-2 border-[#002045] flex items-center justify-between transition-all group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-white/15 text-emerald-400 flex items-center justify-center shrink-0 border border-white/20">
                <LogIn className="w-7 h-7 stroke-[2.5]" />
              </div>
              <div className="text-left">
                <h4 className="font-black text-base leading-tight">
                  {language === 'ph' ? 'LOG ATTENDANCE' : 'LOG ATTENDANCE'}
                </h4>
                <p className="text-xs text-white/80 font-medium mt-0.5">
                  {language === 'ph' ? 'Time In, Break, or Time Out' : 'Record Time-In or Time-Out'}
                </p>
              </div>
            </div>
            <div className="p-2 bg-white/10 rounded-xl group-hover:translate-x-1 transition-transform">
              <ChevronRight className="w-6 h-6 text-white" />
            </div>
          </button>

          {/* Button 2: UPLOAD REPORT */}
          <button
            onClick={() => setCurrentTab('reports')}
            className="w-full h-20 bg-white hover:bg-[#f4f3f7] active:scale-[0.98] text-[#002045] rounded-3xl p-4 shadow-md border-2 border-[#002045] flex items-center justify-between transition-all group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-[#002045] text-white flex items-center justify-center shrink-0">
                <Upload className="w-6 h-6 stroke-[2.5]" />
              </div>
              <div className="text-left">
                <h4 className="font-black text-base text-[#002045] leading-tight">
                  {language === 'ph' ? 'UPLOAD REPORTS' : 'UPLOAD REPORTS'}
                </h4>
                <p className="text-xs text-[#43474e] font-medium mt-0.5">
                  {language === 'ph' ? 'I-pasa ang Accomplishment' : 'Submit daily accomplishment photo'}
                </p>
              </div>
            </div>
            <div className="p-2 bg-[#f4f3f7] rounded-xl group-hover:translate-x-1 transition-transform">
              <ChevronRight className="w-6 h-6 text-[#002045]" />
            </div>
          </button>

          {/* Button 3: REQUEST LEAVE */}
          <button
            onClick={() => setShowLeaveModal(true)}
            className="w-full h-20 bg-white hover:bg-[#f4f3f7] active:scale-[0.98] text-[#1a1c1e] rounded-3xl p-4 shadow-md border-2 border-[#c4c6cf] hover:border-[#002045] flex items-center justify-between transition-all group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-[#f4f3f7] text-[#002045] border border-[#c4c6cf] flex items-center justify-center shrink-0">
                <Calendar className="w-6 h-6 stroke-[2.5]" />
              </div>
              <div className="text-left">
                <h4 className="font-black text-base text-[#002045] leading-tight">
                  {language === 'ph' ? 'REQUEST LEAVE' : 'REQUEST LEAVE'}
                </h4>
                <p className="text-xs text-[#43474e] font-medium mt-0.5">
                  {language === 'ph' ? 'Mag-apply ng Sick o Vacation Leave' : 'Apply for sick or vacation leave'}
                </p>
              </div>
            </div>
            <div className="p-2 bg-[#f4f3f7] rounded-xl group-hover:translate-x-1 transition-transform">
              <ChevronRight className="w-6 h-6 text-[#002045]" />
            </div>
          </button>

          {/* Button 4: REPORT ISSUE */}
          <button
            onClick={() => setShowIssueReportModal(true)}
            className="w-full h-20 bg-[#ffdad6]/60 hover:bg-[#ffdad6] active:scale-[0.98] text-[#93000a] rounded-3xl p-4 shadow-md border-2 border-[#93000a]/30 flex items-center justify-between transition-all group"
          >
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-[#93000a] text-white flex items-center justify-center shrink-0">
                <AlertOctagon className="w-6 h-6 stroke-[2.5]" />
              </div>
              <div className="text-left">
                <h4 className="font-black text-base text-[#93000a] leading-tight">
                  {language === 'ph' ? 'REPORT ISSUE' : 'REPORT ISSUE'}
                </h4>
                <p className="text-xs text-[#93000a]/80 font-medium mt-0.5">
                  {language === 'ph' ? 'I-report ang insidente o problema' : 'Report field issue or hazard'}
                </p>
              </div>
            </div>
            <div className="p-2 bg-white/60 rounded-xl group-hover:translate-x-1 transition-transform">
              <ChevronRight className="w-6 h-6 text-[#93000a]" />
            </div>
          </button>
        </div>
      </section>

      {/* 3. MINIMAL ANNOUNCEMENTS BUTTON */}
      <section className="pt-1">
        <button
          onClick={() => setShowAnnouncementsModal(true)}
          className="w-full bg-white hover:bg-[#f4f3f7] active:scale-[0.98] border-2 border-[#002045] rounded-3xl p-4 shadow-md flex items-center justify-between transition-all group"
        >
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-[#002045] text-white flex items-center justify-center shrink-0 relative">
              <Megaphone className="w-6 h-6 stroke-[2]" />
              {urgentAnnouncementsCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-600 rounded-full border-2 border-white animate-ping" />
              )}
            </div>

            <div className="text-left">
              <div className="flex items-center gap-2">
                <h4 className="font-black text-base text-[#002045]">
                  {language === 'ph' ? 'MGA ANUNSYO' : 'ANNOUNCEMENTS'}
                </h4>
                <span className="bg-[#002045]/10 text-[#002045] font-extrabold text-xs px-2 py-0.5 rounded-full">
                  {announcements.length}
                </span>
              </div>
              <p className="text-xs text-[#43474e] font-medium mt-0.5">
                {language === 'ph'
                  ? 'I-tap para makita ang mga opisyal na abiso'
                  : 'Tap to view official bulletins & alerts'}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 text-xs font-bold text-[#002045] bg-[#f4f3f7] px-3 py-2 rounded-xl group-hover:bg-[#002045] group-hover:text-white transition-colors">
            <span>{language === 'ph' ? 'BUKSAN' : 'VIEW ALL'}</span>
            <ChevronRight className="w-4 h-4" />
          </div>
        </button>
      </section>

      {/* Announcements Modal */}
      <AnnouncementsModal
        isOpen={showAnnouncementsModal}
        onClose={() => setShowAnnouncementsModal(false)}
      />
    </div>
  );
};
