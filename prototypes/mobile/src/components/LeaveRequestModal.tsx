import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { Calendar, Upload, CheckCircle2, Clock, X, Paperclip } from 'lucide-react';
import { LeaveType } from '../types';

export const LeaveRequestModal: React.FC = () => {
  const { showLeaveModal, setShowLeaveModal, leaveRequests, addLeaveRequest } = useApp();

  const [leaveType, setLeaveType] = useState<LeaveType>('Sick Leave');
  const [startDate, setStartDate] = useState<string>('');
  const [endDate, setEndDate] = useState<string>('');
  const [reason, setReason] = useState<string>('');
  const [docAttached, setDocAttached] = useState<boolean>(false);
  const [submittedSuccess, setSubmittedSuccess] = useState<boolean>(false);

  if (!showLeaveModal) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!startDate || !endDate || !reason.trim()) return;

    addLeaveRequest(
      leaveType,
      startDate,
      endDate,
      reason,
      docAttached ? 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=400&auto=format&fit=crop' : undefined
    );

    setSubmittedSuccess(true);
    setStartDate('');
    setEndDate('');
    setReason('');
    setDocAttached(false);

    setTimeout(() => {
      setSubmittedSuccess(false);
      setShowLeaveModal(false);
    }, 2000);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white border border-[#c4c6cf] rounded-2xl max-w-md w-full p-5 flex flex-col gap-4 shadow-xl my-8">
        {/* Header */}
        <div className="flex justify-between items-start border-b border-[#c4c6cf] pb-3">
          <div>
            <h3 className="font-bold text-lg text-[#002045]">Leave Request</h3>
            <p className="text-xs text-[#43474e]">Submit and track your time off</p>
          </div>
          <button
            onClick={() => setShowLeaveModal(false)}
            className="p-1 text-[#5c5e63] hover:text-[#1a1c1e] rounded-full hover:bg-[#f4f3f7]"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {submittedSuccess && (
          <div className="p-3 bg-[#166534] text-white rounded-xl font-bold text-xs flex items-center gap-2 animate-bounce">
            <CheckCircle2 className="w-5 h-5" />
            <span>Leave Request Submitted Successfully!</span>
          </div>
        )}

        {/* Leave Form */}
        <form onSubmit={handleSubmit} className="flex flex-col gap-3">
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#1a1c1e]">Leave Type</label>
            <select
              value={leaveType}
              onChange={(e) => setLeaveType(e.target.value as LeaveType)}
              className="h-11 px-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-semibold text-[#002045] outline-none focus:ring-2 focus:ring-[#002045]"
            >
              <option value="Sick Leave">Sick Leave</option>
              <option value="Vacation Leave">Vacation Leave</option>
              <option value="Emergency Leave">Emergency Leave</option>
              <option value="Other">Other</option>
            </select>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#1a1c1e]">Start Date</label>
              <input
                type="date"
                required
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="h-11 px-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-medium outline-none focus:ring-2 focus:ring-[#002045]"
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#1a1c1e]">End Date</label>
              <input
                type="date"
                required
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="h-11 px-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-medium outline-none focus:ring-2 focus:ring-[#002045]"
              />
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#1a1c1e]">
              Reason <span className="text-[#991b1b]">*</span>
            </label>
            <textarea
              required
              rows={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Provide details for your request..."
              className="p-3 bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl text-xs font-medium text-[#1a1c1e] placeholder:text-[#5c5e63] outline-none focus:ring-2 focus:ring-[#002045] resize-none"
            />
          </div>

          {/* Supporting Document Upload */}
          <div className="flex flex-col gap-1">
            <span className="text-xs font-bold text-[#1a1c1e]">Supporting Document (Optional)</span>
            <button
              type="button"
              onClick={() => setDocAttached(!docAttached)}
              className={`h-11 border-2 border-dashed rounded-xl flex items-center justify-center gap-2 text-xs font-bold transition-all ${
                docAttached
                  ? 'bg-[#166534]/10 border-[#166534] text-[#166534]'
                  : 'bg-[#faf9fd] border-[#c4c6cf] text-[#002045] hover:bg-[#f4f3f7]'
              }`}
            >
              <Paperclip className="w-4 h-4" />
              <span>{docAttached ? 'Proof Image Attached ✓' : 'Attach Proof Image'}</span>
            </button>
          </div>

          <button
            type="submit"
            className="h-12 bg-[#002045] hover:bg-[#1a365d] text-white font-bold text-sm rounded-xl flex items-center justify-center gap-2 mt-2 active:scale-[0.98] transition-all shadow-sm"
          >
            <Upload className="w-4 h-4" />
            <span>Submit Leave Request</span>
          </button>
        </form>

        {/* History Section */}
        <div className="flex flex-col gap-2 pt-2 border-t border-[#c4c6cf]">
          <h4 className="font-bold text-sm text-[#002045]">Recent Requests</h4>
          <div className="flex flex-col gap-2">
            {leaveRequests.map((req) => (
              <div key={req.id} className="bg-[#f4f3f7] border border-[#c4c6cf] rounded-xl p-3 flex justify-between items-start text-xs">
                <div>
                  <p className="font-bold text-[#1a1c1e]">{req.type}</p>
                  <p className="text-[11px] text-[#5c5e63] font-mono mt-0.5">
                    {req.startDate} {req.startDate !== req.endDate ? `to ${req.endDate}` : ''}
                  </p>
                </div>
                <span
                  className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
                    req.status === 'Approved'
                      ? 'bg-[#166534] text-white'
                      : req.status === 'Pending'
                      ? 'bg-[#854d0e] text-white'
                      : 'bg-[#991b1b] text-white'
                  }`}
                >
                  {req.status}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
