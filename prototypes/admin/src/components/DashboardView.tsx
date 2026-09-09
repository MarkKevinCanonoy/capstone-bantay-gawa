import React from 'react';
import { NavPage, AlertItem, RecentActivityItem } from '../types';
import { Download, Plus, ArrowRight, TrendingUp, CheckCircle2, AlertTriangle, Clock, MapPin, Bell } from 'lucide-react';

interface DashboardViewProps {
  onNavigate: (page: NavPage) => void;
  alerts: AlertItem[];
  activities: RecentActivityItem[];
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  onNavigate,
  alerts,
  activities,
  onTriggerToast,
}) => {
  const areaWorkers = [
    { name: 'Downtown Sector A', assigned: 145, present: 142, status: 'OPTIMAL', isError: false },
    { name: 'North Industrial Park', assigned: 89, present: 80, status: 'OPTIMAL', isError: false },
    { name: 'East Side Residential', assigned: 210, present: 195, status: 'UNDERSTAFFED', isError: true },
    { name: 'South Harbor Dock', assigned: 340, present: 338, status: 'OPTIMAL', isError: false },
  ];

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Stat Cards Row */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-gutter">
        {/* Active Workers */}
        <div className="bg-surface-container-lowest border border-outline-variant rounded-lg p-card-padding card-shadow flex flex-col gap-2 relative overflow-hidden">
          <h3 className="font-title-sm text-title-sm text-secondary">Active Workers</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">1,248</span>
            <span className="inline-flex items-center gap-1 font-label-caps text-label-caps text-primary bg-primary/10 px-2 py-1 rounded-full font-bold">
              <TrendingUp className="w-3.5 h-3.5" /> 12%
            </span>
          </div>
        </div>

        {/* Attendance Rate */}
        <div className="bg-surface-container-lowest border border-outline-variant rounded-lg p-card-padding card-shadow flex flex-col gap-2">
          <h3 className="font-title-sm text-title-sm text-secondary">Attendance Rate</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">94.2%</span>
            <span className="inline-flex items-center gap-1 font-label-caps text-label-caps text-primary bg-primary/10 px-2 py-1 rounded-full font-bold">
              <CheckCircle2 className="w-3.5 h-3.5" /> Stable
            </span>
          </div>
        </div>

        {/* Geofence Breaches */}
        <div className="bg-surface-container-lowest border border-outline-variant rounded-lg p-card-padding card-shadow flex flex-col gap-2">
          <h3 className="font-title-sm text-title-sm text-secondary">Geofence Breaches</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">7</span>
            <span className="inline-flex items-center gap-1 font-label-caps text-label-caps text-error bg-error/10 px-2 py-1 rounded-full font-bold">
              <AlertTriangle className="w-3.5 h-3.5" /> Action Req.
            </span>
          </div>
        </div>

        {/* Pending Approvals */}
        <div className="bg-surface-container-lowest border border-outline-variant rounded-lg p-card-padding card-shadow flex flex-col gap-2">
          <h3 className="font-title-sm text-title-sm text-secondary">Pending Approvals</h3>
          <div className="flex items-baseline gap-2">
            <span className="font-display-lg text-display-lg text-on-surface">32</span>
            <span className="inline-flex items-center gap-1 font-label-caps text-label-caps text-on-secondary-container bg-secondary-container px-2 py-1 rounded-full font-bold">
              <Clock className="w-3.5 h-3.5" /> To Review
            </span>
          </div>
        </div>
      </div>

      {/* Quick Action Buttons */}
      <div className="flex flex-wrap gap-4">
        <button
          onClick={() => {
            onTriggerToast('success', 'Exporting workforce summary report PDF...');
            onNavigate('reports');
          }}
          className="bg-primary text-on-primary font-title-sm text-title-sm px-6 py-2.5 rounded flex items-center gap-2 hover:bg-primary-container transition-all shadow-sm cursor-pointer"
        >
          <Download className="w-4 h-4" /> Export Report
        </button>

        <button
          onClick={() => onNavigate('work-areas')}
          className="bg-secondary-container text-on-secondary-container font-title-sm text-title-sm px-6 py-2.5 rounded flex items-center gap-2 hover:bg-secondary-fixed transition-colors cursor-pointer"
        >
          <Plus className="w-4 h-4" /> Add Area
        </button>
      </div>

      {/* Grid: Main Table + Side Feeds */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {/* Main Section: Data Table */}
        <div className="xl:col-span-2 bg-surface-container-lowest border border-outline-variant rounded-lg card-shadow overflow-hidden flex flex-col">
          <div className="p-card-padding border-b border-outline-variant flex justify-between items-center bg-surface">
            <h2 className="font-title-sm text-title-sm text-on-surface font-semibold">Workers by Area</h2>
            <button
              onClick={() => onNavigate('work-areas')}
              className="text-primary hover:text-primary-container font-label-caps text-label-caps flex items-center gap-1 cursor-pointer font-bold"
            >
              View All <ArrowRight className="w-4 h-4" />
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-surface-container-low border-b border-outline-variant font-label-caps text-label-caps text-secondary uppercase tracking-wider">
                  <th className="p-4 font-bold">Area Name</th>
                  <th className="p-4 font-bold">Assigned</th>
                  <th className="p-4 font-bold">Present</th>
                  <th className="p-4 font-bold">Status</th>
                </tr>
              </thead>
              <tbody className="font-body-md text-body-md text-on-surface">
                {areaWorkers.map((row, idx) => (
                  <tr
                    key={idx}
                    className="border-b border-outline-variant h-table-row-height hover:bg-surface-container-low transition-colors"
                  >
                    <td className="p-4 font-medium flex items-center gap-2">
                      <MapPin className="w-4 h-4 text-primary" />
                      {row.name}
                    </td>
                    <td className="p-4 font-data-mono text-data-mono">{row.assigned}</td>
                    <td className="p-4 font-data-mono text-data-mono">{row.present}</td>
                    <td className="p-4">
                      <span
                        className={`inline-flex items-center justify-center px-2.5 py-1 rounded-full font-bold text-[12px] uppercase ${
                          row.isError
                            ? 'bg-error/10 text-error'
                            : 'bg-primary/10 text-primary'
                        }`}
                      >
                        {row.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Side Column: Alerts + Activity */}
        <div className="xl:col-span-1 flex flex-col gap-6">
          {/* Critical Alerts Card */}
          <div className="bg-surface-container-lowest border border-outline-variant rounded-lg card-shadow overflow-hidden">
            <div className="p-4 border-b border-outline-variant bg-surface flex items-center gap-2">
              <Bell className="w-5 h-5 text-error" />
              <h2 className="font-title-sm text-title-sm text-on-surface font-semibold">Critical Alerts</h2>
            </div>

            <ul className="p-4 flex flex-col gap-3">
              {alerts.slice(0, 2).map((alert) => (
                <li
                  key={alert.id}
                  onClick={() => onNavigate('notifications')}
                  className="flex gap-3 p-3 bg-error/5 border border-error/20 rounded-lg hover:bg-error/10 transition-colors cursor-pointer"
                >
                  <AlertTriangle className="w-5 h-5 text-error mt-0.5 shrink-0" />
                  <div>
                    <p className="font-body-sm text-body-sm font-semibold text-on-surface">
                      {alert.type}
                    </p>
                    <p className="font-body-sm text-body-sm text-secondary">
                      {alert.description}
                    </p>
                    <span className="font-label-caps text-label-caps text-secondary mt-1 block">
                      {alert.timeAgo}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          </div>

          {/* Recent Activity Card */}
          <div className="bg-surface-container-lowest border border-outline-variant rounded-lg card-shadow overflow-hidden">
            <div className="p-4 border-b border-outline-variant bg-surface">
              <h2 className="font-title-sm text-title-sm text-on-surface font-semibold">Recent Activity</h2>
            </div>

            <div className="p-4 relative">
              <div className="absolute left-[23px] top-6 bottom-6 w-px bg-outline-variant" />
              <ul className="flex flex-col gap-4 relative z-10">
                {activities.map((act) => (
                  <li key={act.id} className="flex gap-3">
                    <div className="w-6 h-6 rounded-full bg-surface-container-highest border-2 border-surface-container-lowest flex items-center justify-center shrink-0">
                      <div className="w-2 h-2 rounded-full bg-primary" />
                    </div>
                    <div className="pt-0.5">
                      <p className="font-body-sm text-body-sm text-on-surface">
                        <span className="font-semibold">{act.highlightText}</span> {act.text}
                      </p>
                      <span className="font-label-caps text-label-caps text-secondary">
                        {act.timeAgo}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
