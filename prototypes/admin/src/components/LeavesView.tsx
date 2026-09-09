import React, { useState } from 'react';
import { LeaveRequest } from '../types';
import { ZoomIn, Check, X, FileText, User } from 'lucide-react';

interface LeavesViewProps {
  leaveRequests: LeaveRequest[];
  onUpdateLeaveStatus: (id: string, status: 'Approved' | 'Denied') => void;
  searchQuery: string;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const LeavesView: React.FC<LeavesViewProps> = ({
  leaveRequests,
  onUpdateLeaveStatus,
  searchQuery,
  onTriggerToast,
}) => {
  const [selectedDistrict, setSelectedDistrict] = useState<string>('All');
  const [activeDocPreview, setActiveDocPreview] = useState<string | null>(null);

  const districts = ['All Areas', 'North District', 'South District', 'East Zone'];

  const pendingRequests = leaveRequests.filter((r) => r.status === 'Pending');

  const filteredLeaves = leaveRequests.filter((req) => {
    const matchesSearch =
      req.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.type.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.crew.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.district.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesDistrict =
      selectedDistrict === 'All' ||
      selectedDistrict === 'All Areas' ||
      req.district.toLowerCase() === selectedDistrict.toLowerCase();

    return matchesSearch && matchesDistrict;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header & Area Filters */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md font-bold text-primary mb-1">Leave Requests</h2>
          <p className="font-body-sm text-body-sm text-secondary">
            Review and manage pending leave applications.
          </p>
        </div>

        <div className="flex gap-2 overflow-x-auto pb-2 w-full md:w-auto snap-x">
          {districts.map((dist) => {
            const isActive =
              selectedDistrict === dist || (dist === 'All Areas' && selectedDistrict === 'All');
            return (
              <button
                key={dist}
                onClick={() => setSelectedDistrict(dist === 'All Areas' ? 'All' : dist)}
                className={`px-4 py-1.5 rounded-full font-label-caps text-label-caps whitespace-nowrap transition-colors cursor-pointer ${
                  isActive
                    ? 'bg-primary text-on-primary shadow-sm font-bold'
                    : 'bg-surface-container-lowest text-secondary border border-outline-variant hover:bg-surface-container'
                }`}
              >
                {dist}
              </button>
            );
          })}
        </div>
      </div>

      {/* Dashboard Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-surface-container-lowest p-card-padding rounded-xl border border-outline-variant card-shadow">
          <h3 className="font-title-sm text-title-sm text-secondary mb-2">Pending Requests</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-primary">
              {pendingRequests.length}
            </span>
            <span className="font-label-caps text-label-caps text-secondary px-2 py-0.5 bg-surface-container rounded-full font-bold">
              Requires Action
            </span>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-card-padding rounded-xl border border-outline-variant card-shadow">
          <h3 className="font-title-sm text-title-sm text-secondary mb-2">Approved This Week</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">45</span>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-card-padding rounded-xl border border-outline-variant card-shadow">
          <h3 className="font-title-sm text-title-sm text-secondary mb-2">Workers on Leave</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">8</span>
            <span className="font-label-caps text-label-caps text-primary px-2 py-0.5 bg-primary-fixed rounded-full font-bold">
              Today
            </span>
          </div>
        </div>
      </div>

      {/* Leave Request List */}
      <div className="space-y-4">
        {filteredLeaves.map((req) => (
          <div
            key={req.id}
            className="bg-surface-container-lowest rounded-xl border border-outline-variant card-shadow p-5 hover:bg-surface-container-low transition-colors duration-200 flex flex-col lg:flex-row gap-6 items-start lg:items-center"
          >
            {/* Left: Avatar + Details */}
            <div className="flex items-start gap-4 flex-1">
              {req.avatarUrl ? (
                <img
                  src={req.avatarUrl}
                  alt={req.name}
                  className="w-12 h-12 rounded-full object-cover border border-outline-variant shrink-0"
                />
              ) : (
                <div className="w-12 h-12 rounded-full bg-primary-fixed text-primary flex items-center justify-center font-title-sm shrink-0 border border-outline-variant font-bold">
                  {req.initials || req.name[0]}
                </div>
              )}

              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h4 className="font-title-sm text-title-sm text-on-surface font-bold">{req.name}</h4>
                  <span className="px-2 py-0.5 bg-primary/10 text-primary font-label-caps text-[10px] rounded-full font-bold uppercase">
                    {req.type}
                  </span>
                  {req.status !== 'Pending' && (
                    <span
                      className={`px-2 py-0.5 font-label-caps text-[10px] rounded-full font-bold ${
                        req.status === 'Approved' ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {req.status}
                    </span>
                  )}
                </div>

                <p className="font-body-sm text-body-sm text-secondary mb-2">
                  {req.district} • {req.crew}
                </p>

                <p className="font-body-md text-body-md text-on-surface max-w-2xl">
                  {req.reason}
                </p>
              </div>
            </div>

            {/* Dates Requested */}
            <div className="flex flex-col gap-1 lg:w-48 shrink-0 border-l-0 lg:border-l border-outline-variant lg:pl-6">
              <span className="font-label-caps text-label-caps text-secondary uppercase">
                DATES REQUESTED
              </span>
              <span className="font-data-mono text-data-mono text-on-surface font-bold">
                {req.startDate} - {req.endDate}
              </span>
              <span className="font-body-sm text-body-sm text-secondary text-xs">
                {req.duration}
              </span>
            </div>

            {/* Document Thumbnail Preview */}
            <div className="shrink-0">
              {req.docImage ? (
                <div
                  onClick={() => setActiveDocPreview(req.docImage!)}
                  className="group relative cursor-pointer"
                >
                  <img
                    src={req.docImage}
                    alt="Attached Certificate Document"
                    className="w-16 h-16 rounded-lg object-cover border border-outline-variant group-hover:border-primary transition-colors"
                  />
                  <div className="absolute inset-0 bg-on-surface/20 rounded-lg flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                    <ZoomIn className="w-5 h-5 text-white" />
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-center w-16 h-16 rounded-lg border border-outline-variant border-dashed bg-surface text-secondary">
                  <FileText className="w-6 h-6 opacity-40" />
                </div>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-2 w-full lg:w-auto mt-4 lg:mt-0 justify-end shrink-0">
              {req.status === 'Pending' ? (
                <>
                  <button
                    onClick={() => {
                      onUpdateLeaveStatus(req.id, 'Denied');
                      onTriggerToast('error', `Leave request for ${req.name} denied.`);
                    }}
                    className="px-4 py-2 bg-error/10 text-error font-body-sm text-body-sm font-semibold rounded-lg hover:bg-error/20 transition-colors cursor-pointer flex-1 lg:flex-none"
                  >
                    Deny
                  </button>
                  <button
                    onClick={() => {
                      onUpdateLeaveStatus(req.id, 'Approved');
                      onTriggerToast('success', `Leave request for ${req.name} approved!`);
                    }}
                    className="px-4 py-2 bg-primary text-on-primary font-body-sm text-body-sm font-semibold rounded-lg hover:bg-primary/90 transition-all shadow-sm cursor-pointer flex-1 lg:flex-none"
                  >
                    Approve
                  </button>
                </>
              ) : (
                <span className="text-body-sm font-medium text-secondary italic">
                  Status: {req.status}
                </span>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Lightbox Modal for Attached Document */}
      {activeDocPreview && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div
            className="fixed inset-0 bg-black/60 backdrop-blur-xs"
            onClick={() => setActiveDocPreview(null)}
          />

          <div className="relative z-10 max-w-2xl w-full bg-white rounded-2xl p-4 shadow-2xl flex flex-col items-center gap-4">
            <button
              onClick={() => setActiveDocPreview(null)}
              className="absolute top-3 right-3 p-1.5 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-700"
            >
              <X className="w-5 h-5" />
            </button>
            <h4 className="font-title-sm text-title-sm font-bold text-slate-800">Attached Medical Certificate / Document</h4>
            <img
              src={activeDocPreview}
              alt="Medical Certificate Full View"
              className="max-h-[70vh] rounded-lg object-contain border border-slate-200"
            />
          </div>
        </div>
      )}
    </div>
  );
};
