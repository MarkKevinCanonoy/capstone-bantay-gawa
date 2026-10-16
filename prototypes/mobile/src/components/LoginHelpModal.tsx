import React from 'react';
import { HelpCircle, X, QrCode, CheckCircle2, ShieldAlert, Sparkles, Volume2 } from 'lucide-react';
import { useApp } from '../context/AppContext';

interface LoginHelpModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const LoginHelpModal: React.FC<LoginHelpModalProps> = ({ isOpen, onClose }) => {
  const { language } = useApp();

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-fade-in">
      <div className="bg-white border-2 border-[#002045] rounded-3xl max-w-md w-full p-6 shadow-2xl flex flex-col gap-5 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-[#c4c6cf] pb-4">
          <div className="flex items-center gap-2.5">
            <div className="p-2 bg-[#002045] text-white rounded-2xl">
              <HelpCircle className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-extrabold text-lg text-[#002045]">
                {language === 'ph' ? 'Gabay sa Pag-login' : 'Login Guide for Field Workers'}
              </h3>
              <p className="text-xs text-[#43474e]">
                {language === 'ph' ? 'Madaling paraan para sa nakatatanda' : 'Easy steps for scanning your ID'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-10 h-10 rounded-full bg-[#f4f3f7] hover:bg-[#e3e2e6] text-[#002045] font-black text-xl flex items-center justify-center transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Visual Steps List */}
        <div className="flex flex-col gap-4">
          {/* Step 1 */}
          <div className="bg-[#f4f3f7] border border-[#c4c6cf] rounded-2xl p-4 flex gap-3.5 items-start">
            <div className="w-9 h-9 rounded-full bg-[#002045] text-white font-black text-base flex items-center justify-center shrink-0 shadow-sm">
              1
            </div>
            <div>
              <h4 className="font-bold text-sm text-[#002045]">
                {language === 'ph' ? 'Ihanda ang iyong Physical LGU ID' : 'Get your official Physical LGU ID'}
              </h4>
              <p className="text-xs text-[#43474e] mt-1 leading-relaxed">
                {language === 'ph'
                  ? 'Hanapin ang malinaw na QR Code na nakatatak sa harapan o likuran ng iyong physical ID card.'
                  : 'Locate the visible QR Code printed on the front or back of your physical ID badge.'}
              </p>
            </div>
          </div>

          {/* Step 2 */}
          <div className="bg-[#f4f3f7] border border-[#c4c6cf] rounded-2xl p-4 flex gap-3.5 items-start">
            <div className="w-9 h-9 rounded-full bg-[#002045] text-white font-black text-base flex items-center justify-center shrink-0 shadow-sm">
              2
            </div>
            <div>
              <h4 className="font-bold text-sm text-[#002045]">
                {language === 'ph' ? 'Pindutin ang "I-Scan ang ID" na pindutan' : 'Tap the "Scan ID to Login" button'}
              </h4>
              <p className="text-xs text-[#43474e] mt-1 leading-relaxed">
                {language === 'ph'
                  ? 'I-tapat ang camera ng telepono sa QR Code sa distansyang 10-15 cm. Hindi kailangan mag-type ng password!'
                  : 'Hold your phone camera directly over the QR code at a distance of 10-15 cm. No password typing required!'}
              </p>
            </div>
          </div>

          {/* Step 3 */}
          <div className="bg-[#f4f3f7] border border-[#c4c6cf] rounded-2xl p-4 flex gap-3.5 items-start">
            <div className="w-9 h-9 rounded-full bg-[#166534] text-white font-black text-base flex items-center justify-center shrink-0 shadow-sm">
              3
            </div>
            <div>
              <h4 className="font-bold text-sm text-[#166534] flex items-center gap-1.5">
                <span>{language === 'ph' ? 'Magbi-beep at Kumpirmado Agad!' : 'Beep & Instant Verification!'}</span>
                <Volume2 className="w-4 h-4" />
              </h4>
              <p className="text-xs text-[#43474e] mt-1 leading-relaxed">
                {language === 'ph'
                  ? 'Magsasalita o magbi-beep ang telepono kapag nabasa na ang iyong ID, at lalabas ang iyong pangalan at litrato.'
                  : 'Your phone will sound a green confirmation beep and show your photo badge to enter the app.'}
              </p>
            </div>
          </div>
        </div>

        {/* Gallery Option Tip */}
        <div className="bg-[#854d0e]/10 border border-[#854d0e]/30 rounded-2xl p-3.5 flex items-center gap-3">
          <Sparkles className="w-5 h-5 text-[#854d0e] shrink-0" />
          <p className="text-xs text-[#854d0e] font-semibold leading-tight">
            {language === 'ph'
              ? 'May litrato ng ID sa cellphone? Pwedeng gamitin ang "Pumili sa Gallery" na pindutan!'
              : 'Have a photo of your ID saved in your gallery? You can tap "Select from Gallery" anytime!'}
          </p>
        </div>

        {/* Got it button */}
        <button
          onClick={onClose}
          className="w-full h-14 bg-[#002045] hover:bg-[#1a365d] active:scale-[0.98] text-white font-extrabold text-base rounded-2xl shadow-md transition-all flex items-center justify-center gap-2"
        >
          <CheckCircle2 className="w-5 h-5 text-emerald-400" />
          <span>{language === 'ph' ? 'NAINTINDIHAN KO NA / GOT IT' : 'I UNDERSTAND / GOT IT'}</span>
        </button>
      </div>
    </div>
  );
};
