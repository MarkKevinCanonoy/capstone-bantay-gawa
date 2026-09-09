import React, { useState } from 'react';
import { NavPage, AlertItem, BroadcastNotification } from '../types';
import {
  Send,
  Lock,
  Paperclip,
  Link2,
  Bold,
  CheckCircle2,
  AlertTriangle,
  Clock,
  MessageSquare,
  Mail,
  MapPin,
  ShieldAlert,
  Edit3,
} from 'lucide-react';

interface NotificationsViewProps {
  alerts: AlertItem[];
  broadcasts: BroadcastNotification[];
  onAddBroadcast: (bc: BroadcastNotification) => void;
  onNavigate: (page: NavPage) => void;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const NotificationsView: React.FC<NotificationsViewProps> = ({
  alerts,
  broadcasts,
  onAddBroadcast,
  onNavigate,
  onTriggerToast,
}) => {
  const [activeTab, setActiveTab] = useState<'send' | 'alerts'>('send');
  const [selectedRecipient, setSelectedRecipient] = useState('All Employees');
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [confidential, setConfidential] = useState(false);
  const [alertFilter, setAlertFilter] = useState<'All' | 'Geofence' | 'Attendance' | 'Score'>('All');

  const handleSendBroadcast = () => {
    if (!subject.trim() || !body.trim()) {
      onTriggerToast('error', 'Please provide a subject and message body');
      return;
    }

    const newBc: BroadcastNotification = {
      id: `bc-${Date.now()}`,
      recipients: selectedRecipient,
      subject: subject.trim(),
      body: body.trim(),
      timestamp: 'Just now',
      deliveredCount: selectedRecipient === 'All Employees' ? 142 : 18,
      confidential,
    };

    onAddBroadcast(newBc);
    onTriggerToast('success', `Broadcast "${newBc.subject}" sent to ${selectedRecipient}!`);

    // Reset Form
    setSubject('');
    setBody('');
  };

  const filteredAlerts = alerts.filter((alert) => {
    if (alertFilter === 'All') return true;
    if (alertFilter === 'Geofence') return alert.type.includes('Geofence');
    if (alertFilter === 'Attendance') return alert.type.includes('Attendance');
    if (alertFilter === 'Score') return alert.type.includes('Score');
    return true;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Page Header + Custom Tab Navigation */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-on-surface font-bold">
            Communication Center
          </h2>
          <p className="font-body-md text-body-md text-secondary mt-1">
            Manage broadcasts and monitor real-time workforce alerts.
          </p>
        </div>

        {/* Tab Navigation Pill Buttons */}
        <div className="bg-surface-container-low p-1 rounded-lg inline-flex border border-outline-variant shadow-inner">
          <button
            onClick={() => setActiveTab('send')}
            className={`px-6 py-2 rounded-md font-title-sm text-title-sm transition-all duration-200 cursor-pointer ${
              activeTab === 'send'
                ? 'bg-white text-primary shadow-sm border border-outline-variant font-bold'
                : 'text-secondary hover:text-on-surface'
            }`}
          >
            Send Notifications
          </button>

          <button
            onClick={() => setActiveTab('alerts')}
            className={`px-6 py-2 rounded-md font-title-sm text-title-sm transition-all duration-200 cursor-pointer flex items-center gap-2 ${
              activeTab === 'alerts'
                ? 'bg-white text-primary shadow-sm border border-outline-variant font-bold'
                : 'text-secondary hover:text-on-surface'
            }`}
          >
            Active Alerts
            <span className="inline-flex items-center justify-center bg-error-container text-on-error-container text-xs font-bold px-2 py-0.5 rounded-full">
              {alerts.length}
            </span>
          </button>
        </div>
      </div>

      {/* Tab 1: Send Notifications */}
      {activeTab === 'send' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Composer Form */}
          <div className="lg:col-span-2 bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col">
            <div className="p-card-padding border-b border-outline-variant bg-surface-container-low/50">
              <h3 className="font-title-sm text-title-sm text-on-surface font-semibold flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-primary" /> Compose Broadcast
              </h3>
            </div>

            <div className="p-card-padding flex-1 flex flex-col gap-5">
              {/* Recipients */}
              <div>
                <label className="block font-label-caps text-label-caps text-secondary mb-2 uppercase">
                  Recipients
                </label>
                <div className="flex flex-wrap gap-2">
                  {['All Employees', 'Supervisors Only', 'Field Agents (Zone A)', 'Custom'].map((rec) => {
                    const isSelected = selectedRecipient === rec;
                    return (
                      <button
                        key={rec}
                        type="button"
                        onClick={() => setSelectedRecipient(rec)}
                        className={`px-4 py-1.5 rounded-full font-body-sm text-body-sm flex items-center gap-1 font-medium transition-colors cursor-pointer ${
                          isSelected
                            ? 'border-2 border-primary bg-primary/5 text-primary font-bold'
                            : 'border border-outline-variant bg-surface hover:bg-surface-container text-on-surface'
                        }`}
                      >
                        {isSelected && <CheckCircle2 className="w-4 h-4 text-primary" />}
                        {rec}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Subject */}
              <div>
                <label className="block font-label-caps text-label-caps text-secondary mb-2 uppercase">
                  Subject
                </label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="e.g. Mandatory Safety Briefing Tomorrow"
                  className="w-full px-4 py-2.5 bg-surface-container-low border border-outline-variant rounded-lg font-title-sm text-title-sm text-on-surface focus:outline-none focus:border-primary"
                />
              </div>

              {/* Message Body */}
              <div className="flex-1 flex flex-col">
                <div className="flex justify-between items-center mb-2">
                  <label className="block font-label-caps text-label-caps text-secondary uppercase">
                    Message
                  </label>
                  <span className="font-data-mono text-xs text-outline">
                    {body.length} / 500
                  </span>
                </div>

                <textarea
                  rows={6}
                  value={body}
                  maxLength={500}
                  onChange={(e) => setBody(e.target.value)}
                  placeholder="Type your broadcast announcement message here..."
                  className="w-full px-4 py-3 bg-surface-container-low border border-outline-variant rounded-lg font-body-md text-body-md text-on-surface focus:outline-none focus:border-primary resize-none flex-1"
                />

                <div className="mt-3 flex items-center gap-2 text-secondary">
                  <button
                    type="button"
                    onClick={() => onTriggerToast('info', 'File attachment tool opened')}
                    className="p-2 hover:text-primary hover:bg-surface-container rounded"
                    title="Attach File"
                  >
                    <Paperclip className="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() => onTriggerToast('info', 'URL link dialog opened')}
                    className="p-2 hover:text-primary hover:bg-surface-container rounded"
                    title="Insert Link"
                  >
                    <Link2 className="w-4 h-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() => onTriggerToast('info', 'Bold text style toggled')}
                    className="p-2 hover:text-primary hover:bg-surface-container rounded"
                    title="Format Bold"
                  >
                    <Bold className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>

            <div className="p-card-padding border-t border-outline-variant bg-surface-container-low/30 flex items-center justify-between">
              {/* Confidential Toggle */}
              <label className="flex items-center gap-3 cursor-pointer group">
                <input
                  type="checkbox"
                  checked={confidential}
                  onChange={(e) => setConfidential(e.target.checked)}
                  className="w-4 h-4 text-primary rounded"
                />
                <span className="font-body-sm text-body-sm font-medium text-on-surface flex items-center gap-1.5 group-hover:text-primary">
                  <Lock className="w-4 h-4 text-secondary" /> Mark as Confidential
                </span>
              </label>

              <button
                type="button"
                onClick={handleSendBroadcast}
                className="bg-primary hover:bg-primary-container text-on-primary px-6 py-2.5 rounded-lg font-title-sm text-title-sm shadow-sm hover:shadow-md transition-all flex items-center gap-2 cursor-pointer font-bold"
              >
                <Send className="w-4 h-4" /> Send Broadcast
              </button>
            </div>
          </div>

          {/* Recent Sent List */}
          <div className="bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm flex flex-col max-h-[600px]">
            <div className="p-card-padding border-b border-outline-variant flex justify-between items-center bg-surface-container-low/50">
              <h3 className="font-title-sm text-title-sm text-on-surface font-semibold">Recent Sent</h3>
            </div>

            <div className="flex-1 overflow-y-auto divide-y divide-outline-variant">
              {broadcasts.map((bc) => (
                <div key={bc.id} className="p-4 hover:bg-surface-container-low transition-colors cursor-pointer">
                  <div className="flex justify-between items-start mb-1">
                    <span className="font-label-caps text-label-caps text-primary uppercase font-bold">
                      {bc.recipients}
                    </span>
                    <span className="font-data-mono text-data-mono text-secondary">{bc.timestamp}</span>
                  </div>

                  <h4 className="font-title-sm text-title-sm text-on-surface truncate font-semibold flex items-center gap-1">
                    {bc.confidential && <Lock className="w-3.5 h-3.5 text-error shrink-0" />}
                    {bc.subject}
                  </h4>

                  <p className="font-body-sm text-body-sm text-secondary truncate mt-1">
                    {bc.body}
                  </p>

                  <div className="flex items-center gap-1 mt-2 text-xs text-emerald-700 font-medium">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    Delivered to {bc.deliveredCount} recipients
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Tab 2: Active Alerts */}
      {activeTab === 'alerts' && (
        <div className="space-y-6">
          {/* Quick Filters */}
          <div className="flex gap-3 overflow-x-auto pb-2">
            {[
              { id: 'All', label: 'All Alerts', count: alerts.length },
              { id: 'Geofence', label: 'Geofence Breach' },
              { id: 'Attendance', label: 'Attendance' },
              { id: 'Score', label: 'Credit Score' },
            ].map((f) => (
              <button
                key={f.id}
                onClick={() => setAlertFilter(f.id as any)}
                className={`px-4 py-1.5 rounded-full font-label-caps text-label-caps whitespace-nowrap cursor-pointer transition-colors ${
                  alertFilter === f.id
                    ? 'border-2 border-primary bg-primary/5 text-primary font-bold'
                    : 'border border-outline-variant bg-surface hover:bg-surface-container text-on-surface'
                }`}
              >
                {f.label} {f.count !== undefined && <span className="bg-primary text-white rounded-full px-1.5 py-0.5 text-[10px] ml-1">{f.count}</span>}
              </button>
            ))}
          </div>

          {/* Alert Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredAlerts.map((alert) => (
              <div
                key={alert.id}
                className="bg-surface-container-lowest border border-error/30 rounded-xl p-card-padding shadow-md relative overflow-hidden flex flex-col"
              >
                <div className="absolute top-0 left-0 w-1.5 h-full bg-error" />

                <div className="flex justify-between items-start mb-3 pl-2">
                  <div className="flex items-center gap-2">
                    <div className="p-1.5 bg-error-container rounded-md">
                      <ShieldAlert className="w-5 h-5 text-on-error-container" />
                    </div>
                    <span className="font-label-caps text-label-caps text-error uppercase font-bold tracking-wider">
                      {alert.type}
                    </span>
                  </div>
                  <span className="font-data-mono text-data-mono text-secondary">{alert.timeAgo}</span>
                </div>

                <h4 className="font-title-sm text-title-sm text-on-surface pl-2 mb-1 font-bold">
                  {alert.title}
                </h4>

                <p className="font-body-sm text-body-sm text-secondary pl-2 mb-4 flex-1">
                  {alert.description}
                </p>

                {/* Optional Info Section */}
                {alert.workerInfo && (
                  <div className="bg-surface p-3 rounded-lg border border-outline-variant mb-4 pl-2 flex items-center gap-3">
                    {alert.workerInfo.photoUrl ? (
                      <img
                        src={alert.workerInfo.photoUrl}
                        alt={alert.workerInfo.name}
                        className="w-9 h-9 rounded-full border border-outline-variant object-cover"
                      />
                    ) : (
                      <div className="w-9 h-9 rounded-full bg-slate-200 text-slate-700 font-bold flex items-center justify-center">
                        {alert.workerInfo.name[0]}
                      </div>
                    )}
                    <div>
                      <p className="font-body-sm text-body-sm font-medium text-on-surface leading-none">
                        {alert.workerInfo.name}
                      </p>
                      <p className="font-data-mono text-[11px] text-secondary mt-1">
                        ID: {alert.workerInfo.id} • {alert.workerInfo.team}
                      </p>
                    </div>
                  </div>
                )}

                {alert.expected && (
                  <div className="bg-surface p-3 rounded-lg border border-outline-variant mb-4 pl-2 font-data-mono text-xs flex justify-between">
                    <span className="text-secondary">Expected: {alert.expected}</span>
                    <span className="text-error font-bold">Current: {alert.current}</span>
                  </div>
                )}

                {alert.score && (
                  <div className="bg-surface p-3 rounded-lg border border-outline-variant mb-4 pl-2 space-y-1">
                    <div className="flex justify-between items-end">
                      <span className="font-body-sm text-body-sm font-medium">Current Score</span>
                      <span className="font-headline-md text-headline-md text-amber-600 font-bold">
                        {alert.score}%
                      </span>
                    </div>
                    <div className="w-full bg-slate-200 rounded-full h-1.5">
                      <div className="bg-amber-500 h-1.5 rounded-full" style={{ width: `${alert.score}%` }} />
                    </div>
                  </div>
                )}

                {/* Actions */}
                <div className="flex gap-2 pl-2 mt-auto">
                  <button
                    onClick={() => {
                      if (alert.type.includes('Geofence')) onNavigate('work-areas');
                      else if (alert.type.includes('Attendance')) onNavigate('attendance');
                      else onNavigate('reports');
                    }}
                    className="flex-1 bg-surface-container hover:bg-surface-container-high text-on-surface border border-outline-variant px-3 py-2 rounded-lg font-title-sm text-[13px] transition-colors cursor-pointer flex justify-center items-center gap-1 font-semibold"
                  >
                    View Details
                  </button>

                  <button
                    onClick={() =>
                      onTriggerToast('success', `Alert action initiated for "${alert.title}"`)
                    }
                    className="flex-1 bg-error hover:bg-red-800 text-on-error px-3 py-2 rounded-lg font-title-sm text-[13px] shadow-sm transition-colors cursor-pointer flex justify-center items-center gap-1 font-semibold"
                  >
                    Resolve Alert
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
