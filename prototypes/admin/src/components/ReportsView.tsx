import React, { useState } from 'react';
import {
  FileSpreadsheet,
  FileText,
  RefreshCw,
  TrendingUp,
  BarChart2,
  Calendar,
  Filter,
  Eye,
} from 'lucide-react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';

interface ReportsViewProps {
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const ReportsView: React.FC<ReportsViewProps> = ({ onTriggerToast }) => {
  const [reportType, setReportType] = useState('Attendance Summary');
  const [startDate, setStartDate] = useState('2023-10-01');
  const [endDate, setEndDate] = useState('2023-10-31');
  const [department, setDepartment] = useState('All Departments');
  const [previewTitle, setPreviewTitle] = useState('Attendance Summary (Oct 2023)');

  const chartData = [
    { department: 'Field Operations', present: 112, late: 24, absent: 5 },
    { department: 'Engineering', present: 86, late: 12, absent: 8 },
    { department: 'Administration', present: 50, late: 6, absent: 5 },
    { department: 'Security', present: 64, late: 8, absent: 2 },
  ];

  const handleGeneratePreview = () => {
    setPreviewTitle(`${reportType} (${department})`);
    onTriggerToast('success', `Generated report preview for ${reportType}`);
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-on-background font-bold">Reports Engine</h2>
          <p className="font-body-sm text-body-sm text-secondary mt-1">
            Generate, analyze, and export workforce data.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => onTriggerToast('success', 'Exporting Excel workbook (.xlsx)...')}
            className="flex items-center gap-2 px-4 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-primary font-title-sm text-title-sm hover:bg-surface-container-low transition-colors shadow-xs cursor-pointer font-semibold"
          >
            <FileSpreadsheet className="w-4 h-4 text-emerald-700" /> Export to Excel
          </button>

          <button
            onClick={() => onTriggerToast('success', 'Generating PDF report download...')}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-on-primary rounded-lg font-title-sm text-title-sm hover:bg-primary-container transition-colors shadow-md cursor-pointer font-semibold"
          >
            <FileText className="w-4 h-4" /> Export to PDF
          </button>
        </div>
      </div>

      {/* Configuration Card */}
      <div className="bg-white/90 backdrop-blur-md rounded-xl p-card-padding border border-outline-variant shadow-sm space-y-6">
        <h3 className="font-title-sm text-title-sm text-on-surface border-b border-outline-variant pb-3 font-semibold">
          Report Configuration
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Report Type */}
          <div className="flex flex-col gap-2">
            <label className="font-label-caps text-label-caps text-secondary uppercase">
              Report Type
            </label>
            <select
              value={reportType}
              onChange={(e) => setReportType(e.target.value)}
              className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 text-body-md text-on-surface focus:outline-none focus:border-primary cursor-pointer font-medium"
            >
              <option value="Attendance Summary">Attendance Summary</option>
              <option value="Area Performance">Area Performance</option>
              <option value="Leave Utilization">Leave Utilization</option>
              <option value="Incident Logs">Incident Logs</option>
            </select>
          </div>

          {/* Date Range Picker */}
          <div className="flex flex-col gap-2">
            <label className="font-label-caps text-label-caps text-secondary uppercase">
              Date Range
            </label>
            <div className="flex items-center gap-1">
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="w-full bg-surface border border-outline-variant rounded-l-lg px-3 py-2 text-body-sm"
              />
              <span className="bg-surface border-y border-outline-variant py-2 px-2 text-secondary font-body-sm text-xs">
                to
              </span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="w-full bg-surface border border-outline-variant rounded-r-lg px-3 py-2 text-body-sm"
              />
            </div>
          </div>

          {/* Department Filter */}
          <div className="flex flex-col gap-2">
            <label className="font-label-caps text-label-caps text-secondary uppercase">
              Department Filter
            </label>
            <select
              value={department}
              onChange={(e) => setDepartment(e.target.value)}
              className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 text-body-md text-on-surface focus:outline-none focus:border-primary cursor-pointer font-medium"
            >
              <option value="All Departments">All Departments</option>
              <option value="Field Operations">Field Operations</option>
              <option value="Engineering">Engineering</option>
              <option value="Administration">Administration</option>
            </select>
          </div>
        </div>

        <div className="flex justify-end pt-2">
          <button
            onClick={handleGeneratePreview}
            className="flex items-center gap-2 px-6 py-2.5 bg-surface-container-high text-primary rounded-lg font-title-sm text-title-sm hover:bg-surface-variant transition-colors cursor-pointer font-semibold"
          >
            <RefreshCw className="w-4 h-4" /> Generate Preview
          </button>
        </div>
      </div>

      {/* Report Preview Canvas */}
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm flex flex-col min-h-[500px] overflow-hidden">
        <div className="bg-surface-container-low px-6 py-4 border-b border-outline-variant flex justify-between items-center">
          <div className="flex items-center gap-3">
            <Eye className="w-5 h-5 text-primary" />
            <h3 className="font-title-sm text-title-sm text-on-surface font-semibold">
              Preview: {previewTitle}
            </h3>
          </div>
          <span className="bg-primary-container text-on-primary-container px-2.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider">
            LIVE DATA
          </span>
        </div>

        {/* Content Area */}
        <div className="p-6 flex-1 flex flex-col gap-6 bg-surface-container-lowest">
          {/* High level metrics row */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="border border-outline-variant rounded-lg p-4 bg-gradient-to-br from-white to-blue-50/50">
              <p className="font-label-caps text-label-caps text-secondary mb-1 uppercase">Total Employees</p>
              <p className="font-display-lg text-display-lg text-on-surface">248</p>
            </div>

            <div className="border border-outline-variant rounded-lg p-4 bg-gradient-to-br from-white to-blue-50/50">
              <p className="font-label-caps text-label-caps text-secondary mb-1 uppercase">Avg Attendance Rate</p>
              <p className="font-display-lg text-display-lg text-primary">94.2%</p>
              <p className="text-xs text-secondary mt-1 flex items-center gap-1">
                <TrendingUp className="w-3.5 h-3.5 text-emerald-600" /> +1.2% from last month
              </p>
            </div>

            <div className="border border-outline-variant rounded-lg p-4 bg-gradient-to-br from-white to-red-50/50">
              <p className="font-label-caps text-label-caps text-secondary mb-1 uppercase">Total Lates</p>
              <p className="font-display-lg text-display-lg text-error">42</p>
              <p className="text-xs text-secondary mt-1 flex items-center gap-1">
                <TrendingUp className="w-3.5 h-3.5 text-error" /> +5 from last month
              </p>
            </div>

            <div className="border border-outline-variant rounded-lg p-4 bg-gradient-to-br from-white to-blue-50/50">
              <p className="font-label-caps text-label-caps text-secondary mb-1 uppercase">Total Absences</p>
              <p className="font-display-lg text-display-lg text-on-surface">18</p>
            </div>
          </div>

          {/* Recharts Chart Visualization */}
          <div className="p-4 border border-outline-variant rounded-lg bg-surface flex flex-col min-h-[320px]">
            <div className="flex justify-between items-center mb-4">
              <h4 className="font-title-sm text-body-md font-bold text-on-surface flex items-center gap-2">
                <BarChart2 className="w-4 h-4 text-primary" /> Attendance Distribution Graph
              </h4>
            </div>

            <div className="h-[260px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="department" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="present" fill="#00288e" name="Present" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="late" fill="#1e40af" name="Late" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="absent" fill="#ba1a1a" name="Absent" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Data Table Snippet */}
          <div className="border border-outline-variant rounded-lg overflow-hidden">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-surface-container-low border-b border-outline-variant">
                  <th className="py-3 px-4 font-label-caps text-label-caps text-secondary">Department</th>
                  <th className="py-3 px-4 font-label-caps text-label-caps text-secondary">Present</th>
                  <th className="py-3 px-4 font-label-caps text-label-caps text-secondary">Late</th>
                  <th className="py-3 px-4 font-label-caps text-label-caps text-secondary">Absent</th>
                </tr>
              </thead>
              <tbody>
                {chartData.map((row, idx) => (
                  <tr
                    key={idx}
                    className="border-b border-outline-variant hover:bg-surface-container-lowest transition-colors h-[50px]"
                  >
                    <td className="py-3 px-4 font-body-sm text-body-sm text-on-surface font-medium">
                      {row.department}
                    </td>
                    <td className="py-3 px-4 font-data-mono text-data-mono text-on-surface">{row.present}</td>
                    <td className="py-3 px-4 font-data-mono text-data-mono text-on-surface">{row.late}</td>
                    <td className="py-3 px-4 font-data-mono text-data-mono text-on-surface">{row.absent}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};
