import React, { useState } from 'react';
import { Megaphone, X, AlertTriangle, ArrowUpDown, Calendar, Sparkles } from 'lucide-react';
import { useApp } from '../context/AppContext';
import { Announcement } from '../types';

interface AnnouncementsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AnnouncementsModal: React.FC<AnnouncementsModalProps> = ({ isOpen, onClose }) => {
  const { language, announcements } = useApp();
  const [sortBy, setSortBy] = useState<'date-desc' | 'date-asc' | 'priority'>('priority');

  if (!isOpen) return null;

  // Sorting logic
  const sortedAnnouncements = [...announcements].sort((a, b) => {
    if (sortBy === 'priority') {
      if (a.priority === 'high' && b.priority !== 'high') return -1;
      if (a.priority !== 'high' && b.priority === 'high') return 1;
      return 0;
    }
    if (sortBy === 'date-desc') {
      return new Date(b.postedAt).getTime() - new Date(a.postedAt).getTime();
    }
    if (sortBy === 'date-asc') {
      return new Date(a.postedAt).getTime() - new Date(b.postedAt).getTime();
    }
    return 0;
  });

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-fade-in">
      <div className="bg-white border-2 border-[#002045] rounded-3xl max-w-lg w-full p-5 sm:p-6 shadow-2xl flex flex-col gap-4 max-h-[85vh] overflow-hidden">
        {/* Modal Header */}
        <div className="flex items-center justify-between border-b border-[#c4c6cf] pb-3 shrink-0">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-[#002045] text-white rounded-2xl">
              <Megaphone className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-extrabold text-xl text-[#002045]">
                {language === 'ph' ? 'Mga Anunsyo' : 'Announcements'}
              </h3>
              <p className="text-xs text-[#43474e]">
                {language === 'ph' ? 'Opisyal na abiso mula sa LGU Admin' : 'Official LGU bulletins & field alerts'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-11 h-11 rounded-full bg-[#f4f3f7] hover:bg-[#e3e2e6] text-[#002045] font-black text-xl flex items-center justify-center transition-colors active:scale-95"
            aria-label="Close modal"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Sort Controls Bar */}
        <div className="flex items-center justify-between bg-[#f4f3f7] border border-[#c4c6cf] p-2.5 rounded-2xl shrink-0">
          <span className="text-xs font-bold text-[#002045] flex items-center gap-1.5 pl-1">
            <ArrowUpDown className="w-4 h-4 text-[#002045]" />
            <span>{language === 'ph' ? 'I-sort ayon sa:' : 'Sort by:'}</span>
          </span>

          <div className="flex gap-1.5">
            <button
              onClick={() => setSortBy('priority')}
              className={`px-3 py-1.5 rounded-xl font-bold text-xs transition-all ${
                sortBy === 'priority'
                  ? 'bg-[#002045] text-white shadow-xs'
                  : 'bg-white text-[#43474e] border border-[#c4c6cf] hover:bg-gray-100'
              }`}
            >
              {language === 'ph' ? 'Mahalaga Una' : 'Urgent First'}
            </button>
            <button
              onClick={() => setSortBy('date-desc')}
              className={`px-3 py-1.5 rounded-xl font-bold text-xs transition-all ${
                sortBy === 'date-desc'
                  ? 'bg-[#002045] text-white shadow-xs'
                  : 'bg-white text-[#43474e] border border-[#c4c6cf] hover:bg-gray-100'
              }`}
            >
              {language === 'ph' ? 'Pinakabago' : 'Newest'}
            </button>
          </div>
        </div>

        {/* Announcements Scrollable List */}
        <div className="overflow-y-auto flex flex-col gap-3.5 pr-1 flex-1">
          {sortedAnnouncements.map((ann) => (
            <div
              key={ann.id}
              className={`rounded-2xl p-4 border shadow-xs transition-all flex flex-col gap-2 ${
                ann.priority === 'high'
                  ? 'bg-amber-50/80 border-amber-300 ring-1 ring-amber-400/30'
                  : 'bg-white border-[#c4c6cf]'
              }`}
            >
              <div className="flex items-start justify-between gap-2">
                <h4 className="font-extrabold text-base text-[#002045] leading-snug">
                  {ann.title}
                </h4>
                {ann.priority === 'high' && (
                  <span className="bg-[#991b1b] text-white font-extrabold text-[10px] px-2 py-0.5 rounded-full flex items-center gap-1 shrink-0 uppercase tracking-wider">
                    <AlertTriangle className="w-3 h-3" />
                    <span>{language === 'ph' ? 'MAHALAGA' : 'URGENT'}</span>
                  </span>
                )}
              </div>

              <p className="text-sm text-[#1a1c1e] leading-relaxed font-medium">
                {ann.body}
              </p>

              <div className="flex items-center justify-between pt-2 border-t border-[#c4c6cf]/40 text-xs text-[#5c5e63] font-semibold">
                <span className="flex items-center gap-1">
                  <Calendar className="w-3.5 h-3.5 text-[#5c5e63]" />
                  <span>{ann.postedAt}</span>
                </span>
                <span className="text-[11px] font-mono bg-[#f4f3f7] px-2 py-0.5 rounded-md text-[#002045]">
                  LGU Bulletin #{ann.id}
                </span>
              </div>
            </div>
          ))}
        </div>

        {/* Bottom Close Button */}
        <button
          onClick={onClose}
          className="w-full h-14 bg-[#002045] hover:bg-[#1a365d] active:scale-[0.98] text-white font-extrabold text-base rounded-2xl shadow-md transition-all shrink-0 mt-1"
        >
          {language === 'ph' ? 'ISARA' : 'CLOSE ANNOUNCEMENTS'}
        </button>
      </div>
    </div>
  );
};
