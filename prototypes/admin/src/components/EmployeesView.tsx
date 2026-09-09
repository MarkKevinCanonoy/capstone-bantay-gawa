import React, { useState } from 'react';
import { Employee } from '../types';
import {
  Plus,
  Filter,
  Search,
  Camera,
  QrCode,
  X,
  Edit2,
  Trash2,
  UserCheck,
  Building,
} from 'lucide-react';

interface EmployeesViewProps {
  employees: Employee[];
  onAddEmployee: (employee: Employee) => void;
  onDeleteEmployee: (id: string) => void;
  searchQuery: string;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const EmployeesView: React.FC<EmployeesViewProps> = ({
  employees,
  onAddEmployee,
  onDeleteEmployee,
  searchQuery,
  onTriggerToast,
}) => {
  const [modalOpen, setModalOpen] = useState(false);
  const [filterRole, setFilterRole] = useState<string | null>(null);

  // Form State
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [role, setRole] = useState('Field Inspector');
  const [assignedArea, setAssignedArea] = useState('North District, Zone 1');
  const [schedule, setSchedule] = useState('08:00 AM - 05:00 PM');
  const [photoUrl, setPhotoUrl] = useState('');

  const filteredEmployees = employees.filter((emp) => {
    const matchesSearch =
      emp.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      emp.empId.toLowerCase().includes(searchQuery.toLowerCase()) ||
      emp.assignedArea.toLowerCase().includes(searchQuery.toLowerCase()) ||
      emp.role.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesFilter = !filterRole || emp.role.toLowerCase().includes(filterRole.toLowerCase());

    return matchesSearch && matchesFilter;
  });

  const handleSave = () => {
    if (!firstName.trim() || !lastName.trim()) {
      onTriggerToast('error', 'Please provide first name and last name');
      return;
    }

    const newEmp: Employee = {
      id: `emp-${Date.now()}`,
      name: `${firstName.trim()} ${lastName.trim()}`,
      empId: `EMP-2023-${Math.floor(100 + Math.random() * 900)}`,
      role,
      assignedArea,
      schedule,
      status: 'Active',
      photoUrl: photoUrl.trim() || undefined,
      initials: !photoUrl ? `${firstName[0]}${lastName[0]}`.toUpperCase() : undefined,
    };

    onAddEmployee(newEmp);
    onTriggerToast('success', `Employee ${newEmp.name} added successfully!`);
    setModalOpen(false);

    // Reset Form
    setFirstName('');
    setLastName('');
    setPhotoUrl('');
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header Row */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md font-bold text-on-surface">
            Employee Management
          </h2>
          <p className="font-body-sm text-body-sm text-secondary mt-1">
            Manage personnel, roles, and assignments.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setFilterRole(filterRole ? null : 'Field')}
            className={`flex items-center gap-2 px-4 py-2 border rounded-lg font-label-caps text-label-caps transition-colors ${
              filterRole
                ? 'bg-primary text-on-primary border-primary'
                : 'border-outline-variant bg-surface-container-lowest text-secondary hover:bg-surface-container-low'
            }`}
          >
            <Filter className="w-4 h-4" />
            {filterRole ? `Filtered: ${filterRole}` : 'FILTER'}
          </button>

          <button
            onClick={() => setModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-on-primary font-label-caps text-label-caps rounded-lg hover:bg-primary/90 shadow-md transition-all cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            ADD EMPLOYEE
          </button>
        </div>
      </div>

      {/* Bento Stats Row */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-card-padding shadow-sm">
          <p className="font-label-caps text-label-caps text-secondary mb-2 uppercase">TOTAL EMPLOYEES</p>
          <p className="font-display-lg text-display-lg text-on-surface">2,451</p>
        </div>

        <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-card-padding shadow-sm">
          <p className="font-label-caps text-label-caps text-secondary mb-2 uppercase">ACTIVE TODAY</p>
          <p className="font-display-lg text-display-lg text-primary">1,832</p>
        </div>

        <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-card-padding shadow-sm md:col-span-2 flex items-center justify-between">
          <div>
            <p className="font-label-caps text-label-caps text-secondary mb-2 uppercase">QUICK FILTERS</p>
            <div className="flex gap-2 flex-wrap">
              <button
                onClick={() => setFilterRole(filterRole === 'Field' ? null : 'Field')}
                className={`px-3 py-1 rounded-full font-body-sm text-body-sm transition-colors ${
                  filterRole === 'Field'
                    ? 'bg-primary text-on-primary font-bold'
                    : 'bg-surface-container-high text-secondary hover:bg-surface-variant'
                }`}
              >
                Field Workers
              </button>
              <button
                onClick={() => setFilterRole(filterRole === 'Admin' ? null : 'Admin')}
                className={`px-3 py-1 rounded-full font-body-sm text-body-sm transition-colors ${
                  filterRole === 'Admin'
                    ? 'bg-primary text-on-primary font-bold'
                    : 'bg-surface-container-high text-secondary hover:bg-surface-variant'
                }`}
              >
                Office Staff
              </button>
              <button
                onClick={() => setFilterRole(filterRole === 'Security' ? null : 'Security')}
                className={`px-3 py-1 rounded-full font-body-sm text-body-sm transition-colors ${
                  filterRole === 'Security'
                    ? 'bg-primary text-on-primary font-bold'
                    : 'bg-primary/10 text-primary font-bold'
                }`}
              >
                Security & Zone A
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Data Table */}
      <div className="bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-surface-container-low border-b border-outline-variant">
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4">NAME & ID</th>
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4">ROLE</th>
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4">ASSIGNED AREA</th>
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4">SCHEDULE</th>
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4 text-center">STATUS</th>
                <th className="font-label-caps text-label-caps text-secondary px-6 py-4 text-right">ACTIONS</th>
              </tr>
            </thead>
            <tbody className="font-body-sm text-body-sm text-on-surface">
              {filteredEmployees.map((emp) => (
                <tr
                  key={emp.id}
                  className="border-b border-outline-variant hover:bg-surface-container-low transition-colors group"
                >
                  <td className="px-6 py-3">
                    <div className="flex items-center gap-3">
                      {emp.photoUrl ? (
                        <img
                          src={emp.photoUrl}
                          alt={emp.name}
                          className="w-9 h-9 rounded-full object-cover border border-outline-variant shrink-0"
                        />
                      ) : (
                        <div className="w-9 h-9 rounded-full bg-primary/10 text-primary font-bold flex items-center justify-center shrink-0">
                          {emp.initials || emp.name[0]}
                        </div>
                      )}
                      <div>
                        <p className="font-bold text-on-surface">{emp.name}</p>
                        <p className="font-data-mono text-data-mono text-secondary">{emp.empId}</p>
                      </div>
                    </div>
                  </td>

                  <td className="px-6 py-3 font-medium">{emp.role}</td>
                  <td className="px-6 py-3">{emp.assignedArea}</td>
                  <td className="px-6 py-3 font-data-mono text-data-mono text-secondary">{emp.schedule}</td>
                  <td className="px-6 py-3 text-center">
                    <span
                      className={`inline-flex items-center justify-center px-2.5 py-1 rounded-full font-bold text-[12px] ${
                        emp.status === 'Active'
                          ? 'bg-emerald-100 text-emerald-800'
                          : emp.status === 'Leave'
                          ? 'bg-amber-100 text-amber-800'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {emp.status}
                    </span>
                  </td>
                  <td className="px-6 py-3 text-right">
                    <button
                      onClick={() => onDeleteEmployee(emp.id)}
                      className="p-1.5 text-secondary hover:text-error transition-colors rounded hover:bg-error/10"
                      title="Delete Employee"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="px-6 py-4 flex items-center justify-between border-t border-outline-variant bg-surface-container-lowest">
          <p className="font-body-sm text-body-sm text-secondary">
            Showing {filteredEmployees.length} of {employees.length} entries
          </p>
          <div className="flex gap-2">
            <button className="px-3 py-1 border border-outline-variant rounded text-secondary hover:bg-surface-container-low disabled:opacity-50" disabled>
              Prev
            </button>
            <button className="px-3 py-1 bg-primary text-on-primary rounded font-bold">1</button>
            <button className="px-3 py-1 border border-outline-variant rounded text-secondary hover:bg-surface-container-low">2</button>
            <button className="px-3 py-1 border border-outline-variant rounded text-secondary hover:bg-surface-container-low">Next</button>
          </div>
        </div>
      </div>

      {/* Add Employee Modal */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="fixed inset-0 bg-on-surface/40 backdrop-blur-xs" onClick={() => setModalOpen(false)} />

          <div className="relative w-full max-w-2xl bg-surface-container-lowest rounded-2xl shadow-2xl flex flex-col overflow-hidden border border-outline-variant z-10 max-h-[90vh]">
            <div className="flex items-center justify-between px-6 py-4 border-b border-outline-variant bg-surface">
              <h3 className="font-title-sm text-title-sm font-bold text-on-surface">Add New Employee</h3>
              <button onClick={() => setModalOpen(false)} className="p-1.5 text-secondary hover:bg-surface-container-high rounded-full">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-6">
              <div className="flex flex-col md:flex-row gap-6">
                <div className="flex flex-col items-center gap-2 shrink-0">
                  <div className="w-28 h-28 rounded-full bg-surface-container-high border-2 border-dashed border-outline-variant flex flex-col items-center justify-center text-secondary hover:border-primary hover:text-primary transition-colors cursor-pointer group overflow-hidden">
                    {photoUrl ? (
                      <img src={photoUrl} alt="Preview" className="w-full h-full object-cover" />
                    ) : (
                      <>
                        <Camera className="w-8 h-8 mb-1 group-hover:scale-110 transition-transform" />
                        <span className="font-label-caps text-[10px]">PHOTO URL</span>
                      </>
                    )}
                  </div>
                  <input
                    type="text"
                    value={photoUrl}
                    onChange={(e) => setPhotoUrl(e.target.value)}
                    placeholder="Paste image URL..."
                    className="w-36 text-xs px-2 py-1 border border-outline-variant rounded bg-surface text-secondary"
                  />
                </div>

                <div className="flex-1 space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block font-label-caps text-label-caps text-secondary mb-1">FIRST NAME</label>
                      <input
                        type="text"
                        value={firstName}
                        onChange={(e) => setFirstName(e.target.value)}
                        placeholder="e.g. Juan"
                        className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm text-body-sm focus:outline-none focus:border-primary"
                      />
                    </div>
                    <div>
                      <label className="block font-label-caps text-label-caps text-secondary mb-1">LAST NAME</label>
                      <input
                        type="text"
                        value={lastName}
                        onChange={(e) => setLastName(e.target.value)}
                        placeholder="e.g. Dela Cruz"
                        className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm text-body-sm focus:outline-none focus:border-primary"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block font-label-caps text-label-caps text-secondary mb-1">EMPLOYEE ID (AUTO)</label>
                    <input
                      type="text"
                      value="EMP-2023-NEW"
                      disabled
                      className="w-full px-3 py-2 bg-surface-container-low border border-outline-variant rounded-lg font-data-mono text-data-mono text-secondary cursor-not-allowed"
                    />
                  </div>
                </div>
              </div>

              <hr className="border-outline-variant" />

              <h4 className="font-title-sm text-title-sm font-bold text-on-surface">Assignment Details</h4>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block font-label-caps text-label-caps text-secondary mb-1">ROLE / POSITION</label>
                  <select
                    value={role}
                    onChange={(e) => setRole(e.target.value)}
                    className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm text-body-sm focus:outline-none focus:border-primary"
                  >
                    <option value="Field Inspector">Field Inspector</option>
                    <option value="Admin Assistant">Admin Assistant</option>
                    <option value="Security Personnel">Security Personnel</option>
                    <option value="Field Supervisor">Field Supervisor</option>
                    <option value="Maintenance Crew">Maintenance Crew</option>
                  </select>
                </div>

                <div>
                  <label className="block font-label-caps text-label-caps text-secondary mb-1">WORK AREA</label>
                  <select
                    value={assignedArea}
                    onChange={(e) => setAssignedArea(e.target.value)}
                    className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm text-body-sm focus:outline-none focus:border-primary"
                  >
                    <option value="North District, Zone 1">North District, Zone 1</option>
                    <option value="City Hall, Level 2">City Hall, Level 2</option>
                    <option value="South Gate">South Gate</option>
                    <option value="East Side Residential">East Side Residential</option>
                    <option value="South Harbor Dock">South Harbor Dock</option>
                  </select>
                </div>

                <div>
                  <label className="block font-label-caps text-label-caps text-secondary mb-1">SCHEDULE</label>
                  <select
                    value={schedule}
                    onChange={(e) => setSchedule(e.target.value)}
                    className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm text-body-sm focus:outline-none focus:border-primary"
                  >
                    <option value="08:00 AM - 05:00 PM">08:00 AM - 05:00 PM</option>
                    <option value="09:00 AM - 06:00 PM">09:00 AM - 06:00 PM</option>
                    <option value="06:00 PM - 06:00 AM">Night Shift (06 PM - 06 AM)</option>
                  </select>
                </div>
              </div>

              {/* Specialized Bento Actions */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                <button
                  type="button"
                  onClick={() => onTriggerToast('info', 'Face Biometrics embedding registration initialized')}
                  className="flex flex-col items-center justify-center gap-2 p-4 border border-outline-variant bg-surface-container-low rounded-xl hover:bg-surface-container-high transition-colors group cursor-pointer"
                >
                  <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary group-hover:scale-110 transition-transform">
                    <UserCheck className="w-5 h-5" />
                  </div>
                  <span className="font-label-caps text-label-caps font-bold text-on-surface">REGISTER FACE EMBEDDING</span>
                  <span className="font-body-sm text-[12px] text-secondary">Biometric attendance verification</span>
                </button>

                <button
                  type="button"
                  onClick={() => onTriggerToast('success', 'Worker QR Badge Code generated!')}
                  className="flex flex-col items-center justify-center gap-2 p-4 border border-outline-variant bg-surface-container-low rounded-xl hover:bg-surface-container-high transition-colors group cursor-pointer"
                >
                  <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary group-hover:scale-110 transition-transform">
                    <QrCode className="w-5 h-5" />
                  </div>
                  <span className="font-label-caps text-label-caps font-bold text-on-surface">GENERATE WORKER QR CODE</span>
                  <span className="font-body-sm text-[12px] text-secondary">Create printable ID badge code</span>
                </button>
              </div>
            </div>

            <div className="px-6 py-4 border-t border-outline-variant bg-surface flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setModalOpen(false)}
                className="px-4 py-2 font-label-caps text-label-caps text-secondary hover:bg-surface-container-high rounded-lg"
              >
                CANCEL
              </button>
              <button
                type="button"
                onClick={handleSave}
                className="px-6 py-2 bg-primary text-on-primary font-label-caps text-label-caps rounded-lg hover:bg-primary/90 shadow-md transition-all cursor-pointer"
              >
                SAVE EMPLOYEE
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
