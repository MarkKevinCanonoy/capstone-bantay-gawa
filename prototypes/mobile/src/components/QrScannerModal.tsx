import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Camera,
  Image as ImageIcon,
  Zap,
  ZapOff,
  Volume2,
  VolumeX,
  Sparkles,
  CheckCircle2,
  RefreshCw,
  QrCode
} from 'lucide-react';
import { useApp } from '../context/AppContext';

interface QrScannerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onScanSuccess: (qrToken: string) => void;
}

export const QrScannerModal: React.FC<QrScannerModalProps> = ({
  isOpen,
  onClose,
  onScanSuccess
}) => {
  const { language, demoWorkers } = useApp();
  const [flashOn, setFlashOn] = useState<boolean>(false);
  const [soundOn, setSoundOn] = useState<boolean>(true);
  const [isScanning, setIsScanning] = useState<boolean>(true);
  const [scannedResult, setScannedResult] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Play web audio synth beep on scan success
  const playBeep = () => {
    if (!soundOn) return;
    try {
      const ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, ctx.currentTime); // A5 note
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.25);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.25);
    } catch {
      // Audio context fallback
    }
  };

  // Safe Haptic feedback
  const triggerHaptic = () => {
    if ('vibrate' in navigator) {
      try {
        navigator.vibrate([100, 50, 100]);
      } catch {
        // ignore
      }
    }
  };

  // Auto scan simulation timer when modal opens
  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (isOpen && isScanning && !scannedResult) {
      // Simulate automatic detection after 2.8 seconds if user keeps it open
      timer = setTimeout(() => {
        handleDetectToken('QR-LGU-2024-001');
      }, 3500);
    }
    return () => clearTimeout(timer);
  }, [isOpen, isScanning, scannedResult]);

  const handleDetectToken = (token: string) => {
    setIsScanning(false);
    setScannedResult(token);
    playBeep();
    triggerHaptic();

    // Small delay then pass success
    setTimeout(() => {
      onScanSuccess(token);
    }, 1200);
  };

  const handleGalleryUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Pick random demo worker token or mock extracted QR code
      const randomToken = demoWorkers[Math.floor(Math.random() * demoWorkers.length)].qrToken;
      handleDetectToken(randomToken);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex flex-col justify-between p-4 sm:p-6 transition-all">
      {/* Top Navigation Bar in Scanner */}
      <div className="flex items-center justify-between text-white z-10">
        <div className="flex items-center gap-2.5">
          <div className="p-2 rounded-xl bg-white/10 backdrop-blur-md border border-white/20">
            <Camera className="w-5 h-5 text-emerald-400" />
          </div>
          <h3 className="font-bold text-base tracking-wide">
            {language === 'ph' ? 'I-scan ang ID QR' : 'Scan ID QR'}
          </h3>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setFlashOn(!flashOn)}
            className={`p-3 rounded-full transition-all ${
              flashOn ? 'bg-amber-400 text-slate-900 ring-2 ring-amber-300' : 'bg-white/10 text-white hover:bg-white/20'
            }`}
            title={flashOn ? 'Turn Off Flashlight' : 'Turn On Flashlight'}
          >
            {flashOn ? <Zap className="w-5 h-5 fill-current" /> : <ZapOff className="w-5 h-5" />}
          </button>

          <button
            onClick={() => setSoundOn(!soundOn)}
            className={`p-3 rounded-full transition-all ${
              soundOn ? 'bg-emerald-500/20 text-emerald-400 ring-1 ring-emerald-400/40' : 'bg-white/10 text-white/50'
            }`}
            title={soundOn ? 'Mute Beep' : 'Enable Beep Sound'}
          >
            {soundOn ? <Volume2 className="w-5 h-5" /> : <VolumeX className="w-5 h-5" />}
          </button>

          <button
            onClick={onClose}
            className="p-3 bg-white/10 text-white rounded-full hover:bg-white/20 active:scale-95 transition-all"
            aria-label="Close Scanner"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
      </div>

      {/* Main Viewport Area */}
      <div className="relative flex-1 my-3 flex flex-col items-center justify-center overflow-hidden rounded-3xl border-2 border-white/20 bg-slate-950">
        {/* Flashlight simulated overlay */}
        {flashOn && (
          <div className="absolute inset-0 bg-amber-100/10 pointer-events-none transition-opacity duration-300" />
        )}

        {/* Camera Feed Background Mock */}
        <div className="absolute inset-0 bg-linear-to-b from-slate-900 via-slate-950 to-slate-900 opacity-90" />

        {/* Scanner Target Frame */}
        <div className="relative w-64 h-64 sm:w-72 sm:h-72 border-2 border-emerald-400/80 rounded-3xl flex items-center justify-center shadow-[0_0_50px_rgba(16,185,129,0.3)]">
          {/* Corner Guides */}
          <div className="absolute -top-1 -left-1 w-8 h-8 border-t-4 border-l-4 border-emerald-400 rounded-tl-xl" />
          <div className="absolute -top-1 -right-1 w-8 h-8 border-t-4 border-r-4 border-emerald-400 rounded-tr-xl" />
          <div className="absolute -bottom-1 -left-1 w-8 h-8 border-b-4 border-l-4 border-emerald-400 rounded-bl-xl" />
          <div className="absolute -bottom-1 -right-1 w-8 h-8 border-b-4 border-r-4 border-emerald-400 rounded-br-xl" />

          {/* Laser beam animation */}
          {isScanning && !scannedResult && (
            <div className="absolute inset-x-2 h-1 bg-gradient-to-r from-transparent via-emerald-400 to-transparent shadow-[0_0_15px_#10b981] animate-bounce my-auto" />
          )}

          {/* Center Target Icon / Status */}
          {scannedResult ? (
            <div className="flex flex-col items-center justify-center gap-3 text-center p-4 bg-emerald-950/90 rounded-2xl border border-emerald-500/50 shadow-2xl animate-scale-in">
              <div className="w-14 h-14 rounded-full bg-emerald-500 flex items-center justify-center text-slate-950 ring-4 ring-emerald-300/40">
                <CheckCircle2 className="w-9 h-9 stroke-[2.5]" />
              </div>
              <p className="font-extrabold text-lg text-emerald-300">
                {language === 'ph' ? 'BUMASA ANG ID!' : 'ID VERIFIED!'}
              </p>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-2 text-white/60 pointer-events-none text-center px-4">
              <QrCode className="w-16 h-16 opacity-30 stroke-[1.5]" />
              <p className="text-xs font-bold uppercase tracking-wider text-emerald-300/90">
                {language === 'ph' ? 'I-tapat ang ID sa kahon' : 'Align ID inside box'}
              </p>
            </div>
          )}
        </div>

        {/* Quick Demo Scan Buttons inside Scanner */}
        <div className="mt-6 flex gap-2 justify-center px-4">
          {demoWorkers.slice(0, 2).map((w) => (
            <button
              key={w.workerId}
              onClick={() => handleDetectToken(w.qrToken)}
              className="px-3 py-1.5 rounded-xl bg-white/10 hover:bg-emerald-500/20 text-white text-xs font-medium border border-white/10 transition-all active:scale-95 flex items-center gap-1.5"
            >
              <img src={w.photoUrl} alt={w.name} className="w-4 h-4 rounded-full object-cover" />
              <span>{w.name.split(' ')[0]}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Bottom Controls / Gallery Upload Button */}
      <div className="flex flex-col gap-3 z-10 max-w-md mx-auto w-full">
        <input
          type="file"
          ref={fileInputRef}
          onChange={handleGalleryUpload}
          accept="image/*"
          className="hidden"
        />

        <button
          onClick={() => fileInputRef.current?.click()}
          className="w-full h-14 bg-white/15 hover:bg-white/20 active:bg-white/25 text-white font-bold text-sm sm:text-base rounded-2xl border border-white/20 flex items-center justify-center gap-3 transition-all shadow-md"
        >
          <ImageIcon className="w-6 h-6 text-emerald-400" />
          <span>
            {language === 'ph'
              ? 'PUMILI NG LITRATO SA GALLERY'
              : 'SELECT QR PHOTO FROM GALLERY'}
          </span>
        </button>

        <button
          onClick={onClose}
          className="w-full h-12 bg-transparent text-white/70 hover:text-white font-bold text-xs uppercase tracking-wider transition-colors"
        >
          {language === 'ph' ? 'BUMALIK / CANCEL' : 'CANCEL SCAN'}
        </button>
      </div>
    </div>
  );
};
