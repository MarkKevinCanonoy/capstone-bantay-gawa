import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  Upload,
  Camera,
  CheckCircle2,
  Clock,
  XCircle,
  AlertOctagon,
  FileText,
  MapPin,
  Check,
  Plus
} from 'lucide-react';
import { ReportStatus } from '../types';

export const ReportsView: React.FC = () => {
  const {
    accomplishmentReports,
    addAccomplishmentReport,
    setShowIssueReportModal
  } = useApp();

  const [title, setTitle] = useState<string>('');
  const [details, setDetails] = useState<string>('');
  const [photoUrl, setPhotoUrl] = useState<string>(
    'https://images.unsplash.com/photo-1541888946425-d0fbb186a5b3?q=80&w=600&auto=format&fit=crop'
  );
  const [activeFilter, setActiveFilter] = useState<'All' | ReportStatus>('All');
  const [submittedSuccess, setSubmittedSuccess] = useState<boolean>(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !details.trim()) return;

    addAccomplishmentReport(title, details, photoUrl);
    setSubmittedSuccess(true);
    setTitle('');
    setDetails('');

    setTimeout(() => {
      setSubmittedSuccess(false);
    }, 3000);
  };

  const filteredReports = accomplishmentReports.filter((rep) => {
    if (activeFilter === 'All') return true;
    return rep.status === activeFilter;
  });

  return (
    <div className="flex flex-col gap-4 pb-24 max-w-md mx-auto w-full">
      {/* Title & Header */}
      <div className="flex justify-between items-start pt-2">
        <div>
          <h2 className="text-xl font-bold text-[#002045]">Submit Accomplishment</h2>
        </div>

        <button
          onClick={() => setShowIssueReportModal(true)}
          className="px-3 py-1.5 bg-[#ffdad6] text-[#93000a] text-xs font-bold rounded-xl flex items-center gap-1 border border-[#93000a]/20 hover:bg-[#ffdad6]/80 active:scale-95 transition-all shadow-2xs"
        >
          <AlertOctagon className="w-3.5 h-3.5" />
          <span>Report Issue</span>
        </button>
      </div>

      {/* Submission Success Banner */}
      {submittedSuccess && (
        <div className="p-3 bg-[#166534] text-white rounded-xl font-bold text-xs flex items-center gap-2 animate-bounce shadow-md">
          <CheckCircle2 className="w-5 h-5" />
          <span>Accomplishment Report Submitted Successfully!</span>
        </div>
      )}

      {/* Reporting Form Card */}
      <form
        onSubmit={handleSubmit}
        className="bg-white border border-[#c4c6cf] rounded-2xl p-4 shadow-sm flex flex-col gap-3.5"
      >
        {/* Title input */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-bold text-[#1a1c1e]">Task Title</label>
          <input
            type="text"
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="e.g. Drainage Inspection, Road Clearing"
            className="h-11 px-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl font-medium text-xs text-[#1a1c1e] placeholder:text-[#5c5e63] focus:ring-2 focus:ring-[#002045] outline-none"
          />
        </div>

        {/* Photo Proof Component */}
        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-bold text-[#1a1c1e]">Photo Proof (Required Field Capture)</label>
          <div className="relative w-full aspect-video bg-[#2f3033] border border-[#c4c6cf] rounded-xl overflow-hidden flex items-center justify-center group cursor-pointer">
            <img
              src={photoUrl}
              alt="Photo Proof Preview"
              className="w-full h-full object-cover opacity-85 group-hover:scale-105 transition-transform"
            />

            <div className="absolute inset-0 bg-black/40 flex flex-col items-center justify-center gap-1 text-white group-hover:bg-black/20 transition-colors">
              <div className="w-10 h-10 rounded-full bg-black/60 flex items-center justify-center">
                <Camera className="w-5 h-5 text-white" />
              </div>
              <span className="text-xs font-bold">Tap to Capture Field Photo</span>
            </div>
          </div>
        </div>

        {/* Message Field */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-bold text-[#1a1c1e]">Accomplishment Details</label>
          <textarea
            required
            rows={3}
            value={details}
            onChange={(e) => setDetails(e.target.value)}
            placeholder="Describe the specific tasks completed, gear used, or hazards cleared today..."
            className="p-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl font-medium text-xs text-[#1a1c1e] placeholder:text-[#5c5e63] focus:ring-2 focus:ring-[#002045] outline-none resize-none"
          />
        </div>

        {/* Submit Button */}
        <button
          type="submit"
          className="w-full h-12 bg-[#002045] hover:bg-[#1a365d] text-white font-bold text-sm rounded-xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-sm"
        >
          <Upload className="w-4 h-4" />
          <span>Submit Accomplishment</span>
        </button>
      </form>

      {/* History List Section */}
      <section className="flex flex-col gap-3 mt-2">
        <div className="flex justify-between items-center">
          <h3 className="font-bold text-base text-[#002045]">Recent Reports</h3>
          <span className="text-xs font-mono font-semibold bg-[#e9e7eb] text-[#43474e] px-2.5 py-1 rounded-full">
            {accomplishmentReports.length} Total
          </span>
        </div>

        {/* Status Filter Tabs */}
        <div className="flex gap-1.5 border-b border-[#c4c6cf] pb-2 overflow-x-auto">
          {(['All', 'Approved', 'Pending', 'Denied'] as const).map((st) => (
            <button
              key={st}
              onClick={() => setActiveFilter(st)}
              className={`px-3 py-1 rounded-full text-xs font-bold transition-all ${
                activeFilter === st
                  ? 'bg-[#002045] text-white'
                  : 'bg-[#f4f3f7] text-[#43474e] hover:bg-[#e9e7eb]'
              }`}
            >
              {st}
            </button>
          ))}
        </div>

        {/* List items */}
        <div className="flex flex-col gap-2.5">
          {filteredReports.length === 0 ? (
            <div className="p-6 bg-white border border-dashed border-[#c4c6cf] rounded-xl text-center text-xs text-[#5c5e63]">
              No reports found matching status "{activeFilter}".
            </div>
          ) : (
            filteredReports.map((rep) => (
              <div
                key={rep.id}
                className="bg-white border border-[#c4c6cf] rounded-xl p-3.5 flex flex-col gap-2 shadow-2xs"
              >
                <div className="flex justify-between items-start gap-2">
                  <div>
                    <h4 className="font-bold text-sm text-[#1a1c1e]">{rep.title}</h4>
                    <p className="text-[11px] text-[#5c5e63] font-mono mt-0.5">
                      {rep.date} • {rep.time}
                    </p>
                  </div>

                  <span
                    className={`px-2.5 py-1 rounded-md text-[10px] font-bold uppercase tracking-wider flex items-center gap-1 shrink-0 ${
                      rep.status === 'Approved'
                        ? 'bg-[#166534] text-white'
                        : rep.status === 'Pending'
                        ? 'bg-[#854d0e] text-white'
                        : 'bg-[#991b1b] text-white'
                    }`}
                  >
                    {rep.status === 'Approved' ? (
                      <CheckCircle2 className="w-3 h-3" />
                    ) : rep.status === 'Pending' ? (
                      <Clock className="w-3 h-3" />
                    ) : (
                      <XCircle className="w-3 h-3" />
                    )}
                    <span>{rep.status}</span>
                  </span>
                </div>

                <p className="text-xs text-[#43474e] leading-relaxed">{rep.details}</p>

                {/* Denial Reason Alert Box */}
                {rep.status === 'Denied' && rep.denialReason && (
                  <div className="bg-[#ffdad6] border border-[#93000a]/30 text-[#93000a] p-2.5 rounded-lg text-xs font-medium mt-1">
                    <strong className="font-bold">Reason: </strong>
                    {rep.denialReason}
                  </div>
                )}

                {/* GPS Burn Footer */}
                <div className="pt-2 border-t border-[#c4c6cf]/40 font-mono text-[10px] text-[#5c5e63] flex justify-between items-center">
                  <span className="truncate">{rep.gpsBurn}</span>
                </div>
              </div>
            ))
          )}
        </div>
      </section>
    </div>
  );
};
