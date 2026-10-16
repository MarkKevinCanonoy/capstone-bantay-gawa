import React, { useState, useRef } from 'react';
import {
  QrCode,
  Camera,
  Image as ImageIcon,
  HelpCircle,
  CheckCircle2,
  ArrowRight,
  Globe,
  Volume2
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import { QrScannerModal } from '../components/QrScannerModal';
import { LoginHelpModal } from '../components/LoginHelpModal';
import { WorkerProfile } from '../types';

export const LoginView: React.FC = () => {
  const {
    language,
    setLanguage,
    demoWorkers,
    loginWithWorker,
    loginWithQrToken
  } = useApp();

  const [showScanner, setShowScanner] = useState<boolean>(false);
  const [showHelpModal, setShowHelpModal] = useState<boolean>(false);
  const [verifiedWorker, setVerifiedWorker] = useState<WorkerProfile | null>(null);
  const [simulatingScan, setSimulatingScan] = useState<boolean>(false);
  const galleryInputRef = useRef<HTMLInputElement>(null);

  // Play audio verification beep
  const playVerificationBeep = () => {
    try {
      const ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, ctx.currentTime); // C5
      osc.frequency.setValueAtTime(659.25, ctx.currentTime + 0.1); // E5
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.35);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.35);
    } catch {
      // Audio fallback
    }
  };

  const handleScanSuccess = (token: string) => {
    setShowScanner(false);
    const worker = loginWithQrToken(token);
    if (worker) {
      setVerifiedWorker(worker);
      playVerificationBeep();
    }
  };

  const handleDemoBadgeTap = (worker: WorkerProfile) => {
    setSimulatingScan(true);
    setTimeout(() => {
      setSimulatingScan(false);
      setVerifiedWorker(worker);
      playVerificationBeep();
    }, 800);
  };

  const handleGalleryUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Pick random demo worker
      const randomWorker = demoWorkers[Math.floor(Math.random() * demoWorkers.length)];
      setVerifiedWorker(randomWorker);
      playVerificationBeep();
    }
  };

  const handleConfirmLogin = () => {
    if (verifiedWorker) {
      loginWithWorker(verifiedWorker);
    }
  };

  return (
    <div className="min-h-screen bg-[#faf9fd] text-[#1a1c1e] flex flex-col justify-between pb-12 selection:bg-[#002045] selection:text-white">
      {/* Top LGU Header */}
      <header className="bg-white border-b border-[#c4c6cf] px-4 py-3 sticky top-0 z-30 shadow-xs flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-10 h-10 rounded-2xl bg-[#002045] text-[#adc7f7] font-black text-sm flex items-center justify-center shadow-sm border border-[#1a365d]">
            LGU
          </div>
          <div>
            <h1 className="font-extrabold text-base text-[#002045] tracking-tight leading-none">
              BantayGawa
            </h1>
            <p className="text-[11px] font-medium text-[#43474e]">
              {language === 'ph' ? 'LGU Worker Token Login' : 'Civic Field Force Portal'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Language Switcher */}
          <button
            onClick={() => setLanguage(language === 'ph' ? 'en' : 'ph')}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#f4f3f7] border border-[#c4c6cf] text-[#002045] font-bold text-xs hover:bg-[#e9e7eb] active:scale-95 transition-all"
            title="Switch Language"
          >
            <Globe className="w-3.5 h-3.5 text-[#002045]" />
            <span>{language === 'ph' ? 'FILIPINO' : 'ENGLISH'}</span>
          </button>

          {/* Help Button */}
          <button
            onClick={() => setShowHelpModal(true)}
            className="w-9 h-9 rounded-full bg-[#f4f3f7] border border-[#c4c6cf] text-[#002045] flex items-center justify-center hover:bg-[#e9e7eb] active:scale-95 transition-all"
            title="Need Help?"
          >
            <HelpCircle className="w-5 h-5" />
          </button>
        </div>
      </header>

      {/* Main Content Container */}
      <main className="max-w-md mx-auto w-full px-4 my-auto flex flex-col items-center justify-center gap-6 flex-1 py-8">
        {/* Primary Minimal Action Card */}
        <section className="w-full bg-white border-2 border-[#002045] rounded-3xl p-6 sm:p-8 shadow-xl flex flex-col items-center text-center relative">
          <div className="w-20 h-20 rounded-3xl bg-[#002045] text-white flex items-center justify-center mb-4 shadow-md">
            <QrCode className="w-12 h-12 stroke-[2.2]" />
          </div>

          <h2 className="text-2xl sm:text-3xl font-black text-[#002045] tracking-tight">
            {language === 'ph' ? 'I-scan ang ID para Mag-login' : 'Scan ID to Login'}
          </h2>
          <p className="text-sm text-[#43474e] mt-2 max-w-xs font-medium leading-relaxed">
            {language === 'ph'
              ? 'I-tapat ang camera sa QR code sa iyong LGU ID card.'
              : 'Point camera at the QR code on your LGU ID card.'}
          </p>

          {/* MAIN BIG BUTTON: SCAN ID TO LOGIN */}
          <button
            onClick={() => setShowScanner(true)}
            className="w-full mt-6 py-5 px-6 bg-[#002045] hover:bg-[#1a365d] active:scale-[0.98] text-white font-black text-lg sm:text-xl rounded-2xl shadow-xl flex items-center justify-center gap-3.5 transition-all ring-4 ring-[#002045]/20 group"
          >
            <div className="p-2 rounded-xl bg-white/10 group-hover:bg-white/20 transition-colors">
              <Camera className="w-7 h-7 text-emerald-400" />
            </div>
            <span>
              {language === 'ph' ? 'I-SCAN ANG ID' : 'SCAN ID TO LOGIN'}
            </span>
          </button>

          {/* SECONDARY GALLERY UPLOAD BUTTON */}
          <input
            type="file"
            ref={galleryInputRef}
            onChange={handleGalleryUpload}
            accept="image/*"
            className="hidden"
          />
          <button
            onClick={() => galleryInputRef.current?.click()}
            className="w-full mt-3.5 py-4 px-4 bg-[#f4f3f7] hover:bg-[#e9e7eb] active:scale-[0.98] text-[#002045] font-extrabold text-xs sm:text-sm rounded-2xl border border-[#c4c6cf] flex items-center justify-center gap-2.5 transition-all"
          >
            <ImageIcon className="w-5 h-5 text-[#002045]" />
            <span>
              {language === 'ph'
                ? 'PUMILI NG LITRATO SA GALLERY'
                : 'SELECT QR FROM GALLERY'}
            </span>
          </button>
        </section>

        {/* Minimal Quick Test Selector for Browser Testing */}
        <div className="w-full flex items-center justify-between px-2 pt-2 text-xs text-[#74777f]">
          <span className="font-semibold">
            {language === 'ph' ? 'Subukang Worker ID:' : 'Quick Demo Login:'}
          </span>
          <div className="flex gap-2">
            {demoWorkers.slice(0, 2).map((worker) => (
              <button
                key={worker.workerId}
                onClick={() => handleDemoBadgeTap(worker)}
                className="px-2.5 py-1 rounded-lg bg-[#e9e7eb] hover:bg-[#002045] hover:text-white text-[#002045] font-bold text-[11px] transition-all"
              >
                {worker.name.split(' ')[0]}
              </button>
            ))}
          </div>
        </div>
      </main>

      {/* Full Screen Scanner Modal */}
      <QrScannerModal
        isOpen={showScanner}
        onClose={() => setShowScanner(false)}
        onScanSuccess={handleScanSuccess}
      />

      {/* Help Modal */}
      <LoginHelpModal
        isOpen={showHelpModal}
        onClose={() => setShowHelpModal(false)}
      />

      {/* Simulating Scan Overlay */}
      {simulatingScan && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex flex-col items-center justify-center p-6 text-white text-center">
          <div className="w-20 h-20 rounded-3xl border-4 border-emerald-400 border-t-transparent animate-spin mb-4 flex items-center justify-center">
            <QrCode className="w-10 h-10 text-emerald-400" />
          </div>
          <h3 className="font-extrabold text-xl text-emerald-300">
            {language === 'ph' ? 'Binabasa ang QR Code...' : 'Reading QR Token...'}
          </h3>
          <p className="text-xs text-white/70 mt-1">
            {language === 'ph' ? 'Kino-kumpirma ang LGU Physical ID' : 'Validating LGU Credentials'}
          </p>
        </div>
      )}

      {/* Post-Scan Verification Confirmation Modal */}
      {verifiedWorker && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-fade-in">
          <div className="bg-white border-2 border-[#166534] rounded-3xl max-w-sm w-full p-6 shadow-2xl flex flex-col items-center text-center gap-4">
            {/* Top Verified Shield */}
            <div className="w-20 h-20 rounded-full bg-[#166534]/15 text-[#166534] flex items-center justify-center ring-8 ring-[#166534]/10">
              <CheckCircle2 className="w-12 h-12 stroke-[2.5]" />
            </div>

            <div>
              <span className="bg-[#166534] text-white font-extrabold text-[10px] px-3 py-1 rounded-full uppercase tracking-wider">
                {language === 'ph' ? 'NABASA ANG ID BADGE' : 'ID BADGE VERIFIED'}
              </span>
              <h3 className="font-black text-2xl text-[#002045] mt-2">
                {verifiedWorker.name}
              </h3>
              <p className="text-xs font-mono font-bold text-[#43474e] mt-0.5">
                ID: {verifiedWorker.workerId}
              </p>
            </div>

            {/* Worker Avatar & Sector details */}
            <div className="w-full bg-[#f4f3f7] border border-[#c4c6cf] rounded-2xl p-4 flex items-center gap-3.5 text-left">
              <img
                src={verifiedWorker.photoUrl}
                alt={verifiedWorker.name}
                className="w-16 h-16 rounded-xl object-cover border-2 border-[#002045] shrink-0"
              />
              <div className="flex flex-col min-w-0">
                <span className="text-[10px] uppercase font-extrabold text-[#002045] tracking-wider">
                  {verifiedWorker.department}
                </span>
                <p className="font-bold text-xs text-[#1a1c1e] truncate">
                  {verifiedWorker.roleTitle || verifiedWorker.assignedArea}
                </p>
                <p className="text-[11px] text-[#166534] font-semibold mt-0.5">
                  {verifiedWorker.assignedArea} ({verifiedWorker.shift})
                </p>
              </div>
            </div>

            {/* Voice Confirmation hint */}
            <div className="flex items-center gap-2 text-xs text-[#166534] font-bold bg-[#166534]/10 px-3 py-1.5 rounded-full">
              <Volume2 className="w-4 h-4 animate-pulse" />
              <span>
                {language === 'ph'
                  ? `Maligayang pagbabalik, ${verifiedWorker.name.split(' ')[0]}!`
                  : `Welcome back, ${verifiedWorker.name.split(' ')[0]}!`}
              </span>
            </div>

            {/* CONFIRM ENTER APP BUTTON */}
            <button
              onClick={handleConfirmLogin}
              className="w-full mt-2 h-14 bg-[#166534] hover:bg-[#166534]/90 active:scale-[0.98] text-white font-extrabold text-base rounded-2xl shadow-lg flex items-center justify-center gap-2 transition-all ring-4 ring-[#166534]/20"
            >
              <span>
                {language === 'ph' ? 'IPAGPATULOY SA APP' : 'ENTER APP NOW'}
              </span>
              <ArrowRight className="w-5 h-5" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
