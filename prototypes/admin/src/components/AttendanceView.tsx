import React, { useState } from 'react';
import { AttendanceLog } from '../types';
import { Calendar, CheckCircle, Edit3, History, Download, Filter } from 'lucide-react';

interface AttendanceViewProps {
  logs: AttendanceLog[];
  onToggleVerify: (id: string) => void;
  searchQuery: string;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const AttendanceView: React.FC<AttendanceViewProps> = ({
  logs,
  onToggleVerify,
  searchQuery,
  onTriggerToast,
}) => {
  const [selectedDate, setSelectedDate] = useState('2023-10-24');
  const [statusFilter, setStatusFilter] = useState<'All' | 'Verified' | 'Unverified'>('All');

  const filteredLogs = logs.filter((log) => {
    const matchesSearch =
      log.workerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      log.workerId.toLowerCase().includes(searchQuery.toLowerCase()) ||
      log.area.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus = statusFilter === 'All' || log.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md font-bold text-on-surface">Daily Attendance</h2>
          <p className="font-body-sm text-body-sm text-secondary mt-1">
            Review and verify field worker time logs for today.
          </p>
        </div>

        <div className="flex gap-3">
          <div className="relative flex items-center">
            <Calendar className="w-4 h-4 text-secondary absolute left-3 pointer-events-none" />
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => {
                setSelectedDate(e.target.value);
                onTriggerToast('info', `Attendance log date set to ${e.target.value}`);
              }}
              className="pl-9 pr-3 py-2 border border-outline-variant rounded bg-surface-container-lowest text-secondary font-title-sm text-title-sm focus:outline-none"
            />
          </div>

          <button
            onClick={() => onTriggerToast('success', 'Exporting daily attendance CSV report...')}
            className="px-5 py-2 rounded bg-primary text-on-primary font-title-sm text-title-sm hover:bg-primary-container transition-all shadow-sm cursor-pointer"
          >
            Export Report
          </button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-surface-container-lowest p-card-padding rounded-lg border border-outline-variant card-shadow flex flex-col">
          <span className="font-title-sm text-title-sm text-secondary mb-2">Total Logged In</span>
          <div className="flex items-baseline gap-3">
            <span className="font-display-lg text-display-lg text-on-surface">342</span>
            <span className="font-label-caps text-label-caps text-primary bg-surface-container px-2 py-1 rounded-full font-bold">
              94%
            </span>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-card-padding rounded-lg border border-outline-variant card-shadow flex flex-col">
          <span className="font-title-sm text-title-sm text-secondary mb-2">Late Arrivals</span>
          <div className="flex items-baseline gap-3">
            <span className="font-display-lg text-display-lg text-on-surface">18</span>
            <span className="font-label-caps text-label-caps text-error bg-error-container text-on-error-container px-2 py-1 rounded-full font-bold">
              +2
            </span>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-card-padding rounded-lg border border-outline-variant card-shadow flex flex-col">
          <span className="font-title-sm text-title-sm text-secondary mb-2">Unverified Entries</span>
          <div className="flex items-baseline gap-3">
            <span className="font-display-lg text-display-lg text-on-surface">12</span>
            <span className="font-label-caps text-label-caps text-tertiary-container bg-tertiary-fixed px-2 py-1 rounded-full font-bold">
              Action Req
            </span>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-card-padding rounded-lg border border-outline-variant card-shadow flex flex-col">
          <span className="font-title-sm text-title-sm text-secondary mb-2">Active in Field</span>
          <div className="flex items-baseline gap-3">
            <span className="font-display-lg text-display-lg text-on-surface">310</span>
            <span className="font-label-caps text-label-caps text-on-secondary-container bg-secondary-container px-2 py-1 rounded-full font-bold">
              Live
            </span>
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="bg-surface-container-lowest rounded-lg border border-outline-variant card-shadow overflow-hidden flex flex-col">
        <div className="p-4 border-b border-outline-variant flex justify-between items-center bg-surface">
          <h3 className="font-title-sm text-title-sm text-on-surface font-semibold">Log Entries</h3>
          
          <div className="flex items-center gap-2">
            <button
              onClick={() => setStatusFilter(statusFilter === 'Unverified' ? 'All' : 'Unverified')}
              className={`p-1.5 rounded-lg border text-xs font-label-caps font-bold flex items-center gap-1 transition-colors ${
                statusFilter === 'Unverified'
                  ? 'bg-error-container text-on-error-container border-error'
                  : 'border-outline-variant text-secondary hover:text-primary'
              }`}
            >
              <Filter className="w-3.5 h-3.5" />
              {statusFilter === 'Unverified' ? 'Showing Unverified' : 'Filter Status'}
            </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead className="bg-surface-container border-b border-outline-variant">
              <tr>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant w-1/4">Worker</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Area</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Time-in</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Break-in</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Break-out</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Time-out</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant">Status</th>
                <th className="px-6 py-3 font-label-caps text-label-caps text-on-surface-variant text-right">Actions</th>
              </tr>
            </thead>

            <tbody className="font-body-sm text-body-sm text-on-surface">
              {filteredLogs.map((log) => {
                const isLate = log.hasWarning || log.timeIn.includes('08:45');
                return (
                  <tr
                    key={log.id}
                    className="h-table-row-height border-b border-outline-variant hover:bg-surface-container-low transition-colors group"
                  >
                    <td className="px-6 py-2">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded bg-tertiary-fixed flex items-center justify-center text-on-tertiary-fixed font-title-sm text-title-sm font-bold shrink-0">
                          {log.initials}
                        </div>
                        <div className="flex flex-col">
                          <span className="font-medium text-on-surface">{log.workerName}</span>
                          <span className="text-secondary font-label-caps text-[10px]">ID: {log.workerId}</span>
                        </div>
                      </div>
                    </td>

                    <td className="px-6 py-2 text-secondary font-medium">{log.area}</td>
                    <td className={`px-6 py-2 font-data-mono text-data-mono ${isLate ? 'text-error font-bold' : ''}`}>
                      {log.timeIn}
                    </td>
                    <td className="px-6 py-2 font-data-mono text-data-mono text-secondary">{log.breakIn}</td>
                    <td className="px-6 py-2 font-data-mono text-data-mono text-secondary">{log.breakOut}</td>
                    <td className={`px-6 py-2 font-data-mono text-data-mono ${log.timeOut === 'Missing' ? 'text-error font-bold' : ''}`}>
                      {log.timeOut}
                    </td>

                    <td className="px-6 py-2">
                      <span
                        className={`inline-flex items-center justify-center px-2.5 py-1 rounded-full font-label-caps text-[11px] font-bold ${
                          log.status === 'Verified'
                            ? 'bg-primary-container text-on-primary-container'
                            : 'bg-error-container text-on-error-container'
                        }`}
                      >
                        {log.status}
                      </span>
                    </td>

                    <td className="px-6 py-2 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => onTriggerToast('info', `Log edit modal opened for ${log.workerName}`)}
                          className="text-secondary hover:text-primary p-1"
                          title="Edit Log"
                        >
                          <Edit3 className="w-4 h-4" />
                        </button>

                        <button
                          onClick={() => {
                            onToggleVerify(log.id);
                            onTriggerToast(
                              'success',
                              `Status for ${log.workerName} updated to ${
                                log.status === 'Verified' ? 'Unverified' : 'Verified'
                              }`
                            );
                          }}
                          className={`p-1 transition-colors ${
                            log.status === 'Verified' ? 'text-emerald-600' : 'text-error hover:text-emerald-600'
                          }`}
                          title="Toggle Verification"
                        >
                          <CheckCircle className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-outline-variant bg-surface flex justify-between items-center text-secondary font-body-sm text-body-sm">
          <span>Showing 1 to {filteredLogs.length} of {logs.length} entries</span>
          <div className="flex gap-1">
            <button className="p-1 rounded hover:bg-surface-container-high transition-colors disabled:opacity-50" disabled>
              Prev
            </button>
            <button className="w-8 h-8 rounded bg-primary-container text-on-primary-container font-medium flex items-center justify-center">1</button>
            <button className="w-8 h-8 rounded hover:bg-surface-container-high transition-colors flex items-center justify-center">2</button>
            <button className="p-1 rounded hover:bg-surface-container-high transition-colors">Next</button>
          </div>
        </div>
      </div>
    </div>
  );
};
