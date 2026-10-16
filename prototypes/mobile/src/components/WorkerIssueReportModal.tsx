import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { AlertOctagon, Camera, Send, X, Search, CheckCircle2 } from 'lucide-react';
import { WorkerIssueReport } from '../types';

export const WorkerIssueReportModal: React.FC = () => {
  const {
    showIssueReportModal,
    setShowIssueReportModal,
    addWorkerIssueReport,
    userCoords
  } = useApp();

  const [workerName, setWorkerName] = useState<string>('Juan Dela Cruz');
  const [workerId, setWorkerId] = useState<string>('2024-042');
  const [issueType, setIssueType] = useState<WorkerIssueReport['issueType']>('Not working / Loitering');
  const [description, setDescription] = useState<string>('');
  const [hasPhoto, setHasPhoto] = useState<boolean>(true);
  const [submittedSuccess, setSubmittedSuccess] = useState<boolean>(false);

  if (!showIssueReportModal) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!description.trim()) return;

    addWorkerIssueReport(
      workerName,
      workerId,
      issueType,
      description,
      hasPhoto ? 'https://images.unsplash.com/photo-1541888946425-d0fbb186a5b3?q=80&w=400&auto=format&fit=crop' : undefined
    );

    setSubmittedSuccess(true);
    setDescription('');

    setTimeout(() => {
      setSubmittedSuccess(false);
      setShowIssueReportModal(false);
    }, 2000);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white border border-[#c4c6cf] rounded-2xl max-w-md w-full p-5 flex flex-col gap-4 shadow-xl my-8">
        {/* Header */}
        <div className="flex justify-between items-start border-b border-[#c4c6cf] pb-3">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-[#ffdad6] text-[#93000a] flex items-center justify-center">
              <AlertOctagon className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-lg text-[#002045]">Report Issue</h3>
              <p className="text-xs text-[#43474e]">Civic Oversight & Field Integrity</p>
            </div>
          </div>

          <button
            onClick={() => setShowIssueReportModal(false)}
            className="p-1 text-[#5c5e63] hover:text-[#1a1c1e] rounded-full hover:bg-[#f4f3f7]"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {submittedSuccess && (
          <div className="p-3 bg-[#166534] text-white rounded-xl font-bold text-xs flex items-center gap-2 animate-bounce">
            <CheckCircle2 className="w-5 h-5" />
            <span>Civic Oversight Report Filed Successfully!</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          {/* Worker Search Select */}
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#1a1c1e]">Select Worker / Personnel</label>
            <div className="relative">
              <Search className="w-4 h-4 text-[#5c5e63] absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                value={`${workerName} (ID: ${workerId})`}
                onChange={(e) => setWorkerName(e.target.value)}
                placeholder="Search by worker name or ID..."
                className="w-full h-11 pl-9 pr-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-semibold text-[#002045] outline-none focus:ring-2 focus:ring-[#002045]"
              />
            </div>
          </div>

          {/* Issue Type Category */}
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#1a1c1e]">Issue Category</label>
            <select
              value={issueType}
              onChange={(e) => setIssueType(e.target.value as WorkerIssueReport['issueType'])}
              className="h-11 px-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-semibold text-[#002045] outline-none focus:ring-2 focus:ring-[#002045]"
            >
              <option value="Not working / Loitering">Not working / Loitering</option>
              <option value="Absent from designated area">Absent from designated area</option>
              <option value="Safety violation">Safety violation</option>
              <option value="Other">Other (specify details below)</option>
            </select>
          </div>

          {/* Description */}
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#1a1c1e]">Description</label>
            <textarea
              required
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Describe the situation in detail..."
              className="p-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-medium text-[#1a1c1e] placeholder:text-[#5c5e63] outline-none focus:ring-2 focus:ring-[#002045] resize-none"
            />
          </div>

          {/* Photo Evidence Upload Area */}
          <div className="flex flex-col gap-1">
            <div className="flex justify-between items-center">
              <span className="text-xs font-bold text-[#1a1c1e]">Evidence Photo</span>
              <span className="text-[10px] font-mono text-[#991b1b] font-bold">(Required)</span>
            </div>

            <button
              type="button"
              onClick={() => setHasPhoto(!hasPhoto)}
              className="min-h-[120px] border-2 border-dashed border-[#c4c6cf] hover:border-[#002045] rounded-xl bg-[#faf9fd] flex flex-col items-center justify-center gap-2 p-3 transition-colors"
            >
              <div className="w-10 h-10 rounded-full bg-[#efedf1] flex items-center justify-center text-[#002045]">
                <Camera className="w-5 h-5" />
              </div>
              <div className="text-center">
                <p className="text-xs font-bold text-[#002045]">
                  {hasPhoto ? 'Photo Attached (GPS Burn Active)' : 'Tap to Take Photo or Upload'}
                </p>
                <p className="text-[10px] text-[#5c5e63] mt-0.5 font-mono">
                  Metadata (GPS: {userCoords.lat}, {userCoords.lng}) will be logged automatically.
                </p>
              </div>
            </button>
          </div>

          <button
            type="submit"
            className="h-12 bg-[#002045] hover:bg-[#1a365d] text-white font-bold text-sm rounded-xl flex items-center justify-center gap-2 mt-2 active:scale-[0.98] transition-all shadow-sm"
          >
            <Send className="w-4 h-4" />
            <span>Submit Report</span>
          </button>
        </form>
      </div>
    </div>
  );
};
