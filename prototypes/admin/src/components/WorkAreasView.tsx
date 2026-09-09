import React, { useState } from 'react';
import { WorkArea } from '../types';
import {
  MapPin,
  Circle,
  Shapes,
  Trash2,
  CheckCircle2,
  PauseCircle,
  UserPlus,
  ChevronDown,
  Plus,
} from 'lucide-react';

interface WorkAreasViewProps {
  workAreas: WorkArea[];
  onUpdateWorkArea: (updated: WorkArea) => void;
  onAddWorkArea: (area: WorkArea) => void;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const WorkAreasView: React.FC<WorkAreasViewProps> = ({
  workAreas,
  onUpdateWorkArea,
  onAddWorkArea,
  onTriggerToast,
}) => {
  const [selectedAreaId, setSelectedAreaId] = useState<string>('area-1');
  const [activeTool, setActiveTool] = useState<'polygon' | 'circle' | null>('circle');
  const [newAreaModalOpen, setNewAreaModalOpen] = useState(false);

  // New Area Form State
  const [newAreaName, setNewAreaName] = useState('');
  const [newAreaSqKm, setNewAreaSqKm] = useState('2.5');
  const [newAreaSupervisor, setNewAreaSupervisor] = useState('J. Reyes');

  const mapBgUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuArCpbuNIgJ5NjIDM85iHnEjhh1s7n6n8bt0dDWnIA7jkcHMU0m0nyI2nXlO8OCfbAgoHDIF3fgvODM6QrBTg8kkRW1KrK8_x7uHybzvi6QvUeTYYwzm0DCwQEg1hUcsvfRj8ihQ9Qp7ZxTyvQbIBku3VN8TspS7-eIHpRVo7SygZ5YQpmN0_A4z4ToygNuVkPxutt74YZqVtkSEihGMSMo-tyd4jXMxDZ2MJfgh-WR0P0TAOeqVtlyCajj4AreEVdj69NbFEz8K0UQ';

  const handleSupervisorChange = (area: WorkArea, supervisorName: string) => {
    const updated = { ...area, supervisorName };
    onUpdateWorkArea(updated);
    onTriggerToast('success', `Supervisor for ${area.name} set to ${supervisorName}`);
  };

  const handleToggleStatus = (area: WorkArea) => {
    const nextStatus: 'Active' | 'Inactive' = area.status === 'Active' ? 'Inactive' : 'Active';
    const updated = { ...area, status: nextStatus };
    onUpdateWorkArea(updated);
    onTriggerToast('info', `${area.name} status changed to ${nextStatus}`);
  };

  const handleAddWorker = (area: WorkArea) => {
    const updated = { ...area, assignedCount: area.assignedCount + 1 };
    onUpdateWorkArea(updated);
    onTriggerToast('success', `Assigned new worker to ${area.name}`);
  };

  const handleCreateArea = () => {
    if (!newAreaName.trim()) {
      onTriggerToast('error', 'Area name is required');
      return;
    }

    const created: WorkArea = {
      id: `area-${Date.now()}`,
      name: newAreaName.trim(),
      areaSqKm: `${newAreaSqKm} sq km`,
      status: 'Active',
      supervisorName: newAreaSupervisor,
      assignedCount: 1,
    };

    onAddWorkArea(created);
    setSelectedAreaId(created.id);
    onTriggerToast('success', `New Geofence Area "${created.name}" created!`);
    setNewAreaModalOpen(false);
    setNewAreaName('');
  };

  return (
    <div className="flex flex-col lg:flex-row h-[calc(100vh-100px)] rounded-xl border border-outline-variant overflow-hidden bg-surface-container-lowest animate-fadeIn">
      {/* Left: Map Canvas */}
      <div className="flex-1 relative bg-surface-container-low min-h-[350px]">
        {/* Map Background */}
        <img
          src={mapBgUrl}
          alt="District Geofence Map Canvas"
          className="w-full h-full object-cover absolute inset-0 opacity-85"
        />

        {/* Floating Drawing Tools */}
        <div className="absolute top-4 left-4 bg-white/90 backdrop-blur-md p-2 rounded-xl shadow-lg border border-outline-variant flex flex-col gap-2 z-10">
          <button
            onClick={() => {
              setActiveTool('polygon');
              onTriggerToast('info', 'Polygon Tool active: Click map to draw boundary');
            }}
            className={`p-3 rounded-lg transition-all relative group ${
              activeTool === 'polygon'
                ? 'bg-primary text-on-primary shadow-sm'
                : 'text-secondary hover:text-primary hover:bg-surface-container'
            }`}
            title="Draw Polygon Boundary"
          >
            <Shapes className="w-5 h-5" />
            <span className="absolute left-full ml-2 top-1/2 -translate-y-1/2 bg-inverse-surface text-inverse-on-surface px-2 py-1 rounded text-xs opacity-0 pointer-events-none group-hover:opacity-100 transition-opacity whitespace-nowrap z-20">
              Draw Polygon
            </span>
          </button>

          <button
            onClick={() => {
              setActiveTool('circle');
              onTriggerToast('info', 'Circle Geofence Tool active: Drag radius on map');
            }}
            className={`p-3 rounded-lg transition-all relative group ${
              activeTool === 'circle'
                ? 'bg-primary text-on-primary shadow-sm'
                : 'text-secondary hover:text-primary hover:bg-surface-container'
            }`}
            title="Draw Circular Geofence"
          >
            <Circle className="w-5 h-5" />
            <span className="absolute left-full ml-2 top-1/2 -translate-y-1/2 bg-inverse-surface text-inverse-on-surface px-2 py-1 rounded text-xs opacity-0 pointer-events-none group-hover:opacity-100 transition-opacity whitespace-nowrap z-20">
              Draw Circle
            </span>
          </button>

          <div className="h-px bg-outline-variant w-full my-1" />

          <button
            onClick={() => {
              setActiveTool(null);
              onTriggerToast('info', 'Geofence overlays cleared from workspace');
            }}
            className="p-3 text-secondary hover:text-error hover:bg-error-container/20 rounded-lg transition-colors relative group"
            title="Clear Map Drawings"
          >
            <Trash2 className="w-5 h-5" />
            <span className="absolute left-full ml-2 top-1/2 -translate-y-1/2 bg-inverse-surface text-inverse-on-surface px-2 py-1 rounded text-xs opacity-0 pointer-events-none group-hover:opacity-100 transition-opacity whitespace-nowrap z-20">
              Clear Map
            </span>
          </button>
        </div>

        {/* Circular Geofence Visual Overlay */}
        <div className="absolute top-[35%] left-[38%] w-56 h-56 border-2 border-primary bg-primary/15 rounded-full flex items-center justify-center -translate-x-1/2 -translate-y-1/2 pointer-events-none shadow-md animate-pulse">
          <div className="w-7 h-7 rounded-full bg-white border-2 border-primary flex items-center justify-center text-primary shadow-lg">
            <MapPin className="w-4 h-4 fill-primary" />
          </div>
        </div>

        {/* Polygon Geofence Visual Overlay */}
        <div className="absolute top-[60%] left-[62%] w-48 h-32 border-2 border-primary bg-primary/15 rounded-xl rotate-12 flex items-center justify-center pointer-events-none shadow-md">
          <div className="w-7 h-7 rounded-full bg-white border-2 border-primary flex items-center justify-center text-primary shadow-lg">
            <MapPin className="w-4 h-4 fill-primary" />
          </div>
        </div>
      </div>

      {/* Right Side Panel: Area Management List */}
      <div className="w-full lg:w-[380px] bg-surface-container-lowest border-t lg:border-t-0 lg:border-l border-outline-variant flex flex-col h-full shrink-0">
        <div className="p-card-padding border-b border-outline-variant bg-surface flex justify-between items-center">
          <div>
            <h2 className="font-headline-md text-headline-md text-on-surface font-bold">Work Areas</h2>
            <p className="font-body-sm text-body-sm text-secondary">Manage geofences and team assignments</p>
          </div>
          <button
            onClick={() => setNewAreaModalOpen(true)}
            className="p-2 bg-primary text-on-primary rounded-lg hover:bg-primary-container shadow-sm transition-colors cursor-pointer"
            title="Create New Geofence Area"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-card-padding space-y-4">
          {workAreas.map((area) => {
            const isSelected = area.id === selectedAreaId;
            return (
              <div
                key={area.id}
                onClick={() => setSelectedAreaId(area.id)}
                className={`border rounded-xl p-4 shadow-xs transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-surface-container-low border-primary border-l-4'
                    : 'bg-surface-container-lowest border-outline-variant hover:border-primary/50'
                } ${area.status === 'Inactive' ? 'opacity-70' : ''}`}
              >
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <h3 className="font-title-sm text-title-sm text-on-surface font-bold">{area.name}</h3>
                    <div className="font-data-mono text-data-mono text-secondary mt-0.5">
                      Area: {area.areaSqKm}
                    </div>
                  </div>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleToggleStatus(area);
                    }}
                    className={`px-2 py-1 rounded-full font-label-caps text-label-caps flex items-center gap-1 font-bold ${
                      area.status === 'Active'
                        ? 'bg-primary/10 text-primary'
                        : 'bg-slate-200 text-slate-600'
                    }`}
                  >
                    {area.status === 'Active' ? (
                      <CheckCircle2 className="w-3.5 h-3.5" />
                    ) : (
                      <PauseCircle className="w-3.5 h-3.5" />
                    )}
                    {area.status}
                  </button>
                </div>

                <div className="h-px bg-outline-variant w-full my-3" />

                <div className="space-y-3">
                  {/* Supervisor */}
                  <div className="flex items-center justify-between">
                    <span className="font-body-sm text-body-sm text-secondary">Supervisor</span>
                    <div
                      onClick={(e) => e.stopPropagation()}
                      className="relative flex items-center gap-2 bg-surface px-2.5 py-1 rounded border border-outline-variant"
                    >
                      {area.supervisorPhoto && (
                        <img
                          src={area.supervisorPhoto}
                          alt={area.supervisorName}
                          className="w-5 h-5 rounded-full object-cover shrink-0"
                        />
                      )}
                      <select
                        value={area.supervisorName}
                        onChange={(e) => handleSupervisorChange(area, e.target.value)}
                        className="bg-transparent font-body-sm text-body-sm font-medium text-on-surface border-none focus:ring-0 pr-4 cursor-pointer"
                      >
                        <option value="J. Reyes">J. Reyes</option>
                        <option value="M. Santos">M. Santos</option>
                        <option value="R. Reyes">R. Reyes</option>
                        <option value="S. Jenkins">S. Jenkins</option>
                        <option value="P. Torres">P. Torres</option>
                        <option value="Unassigned">Unassigned</option>
                      </select>
                      <ChevronDown className="w-3.5 h-3.5 text-secondary absolute right-1 pointer-events-none" />
                    </div>
                  </div>

                  {/* Workers Assigned */}
                  <div className="flex items-center justify-between">
                    <span className="font-body-sm text-body-sm text-secondary">Workers Assigned</span>
                    <div className="flex items-center gap-2">
                      <span className="font-data-mono text-data-mono font-bold text-on-surface">
                        {area.assignedCount}
                      </span>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleAddWorker(area);
                        }}
                        className="text-primary hover:text-primary-container p-1 rounded hover:bg-surface-container transition-colors"
                        title="Assign Worker"
                      >
                        <UserPlus className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* New Area Modal */}
      {newAreaModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="fixed inset-0 bg-on-surface/40 backdrop-blur-xs" onClick={() => setNewAreaModalOpen(false)} />

          <div className="relative w-full max-w-md bg-surface-container-lowest rounded-2xl shadow-xl p-6 border border-outline-variant z-10 space-y-4">
            <h3 className="font-title-sm text-title-sm font-bold text-on-surface">Create New Work Geofence Zone</h3>

            <div className="space-y-3">
              <div>
                <label className="block font-label-caps text-label-caps text-secondary mb-1">AREA NAME</label>
                <input
                  type="text"
                  value={newAreaName}
                  onChange={(e) => setNewAreaName(e.target.value)}
                  placeholder="e.g. Sector 5 - West Port"
                  className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm"
                />
              </div>

              <div>
                <label className="block font-label-caps text-label-caps text-secondary mb-1">ESTIMATED SQ KM</label>
                <input
                  type="text"
                  value={newAreaSqKm}
                  onChange={(e) => setNewAreaSqKm(e.target.value)}
                  className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm"
                />
              </div>

              <div>
                <label className="block font-label-caps text-label-caps text-secondary mb-1">ASSIGN SUPERVISOR</label>
                <select
                  value={newAreaSupervisor}
                  onChange={(e) => setNewAreaSupervisor(e.target.value)}
                  className="w-full px-3 py-2 bg-surface border border-outline-variant rounded-lg font-body-sm"
                >
                  <option value="J. Reyes">J. Reyes</option>
                  <option value="M. Santos">M. Santos</option>
                  <option value="S. Jenkins">S. Jenkins</option>
                </select>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setNewAreaModalOpen(false)}
                className="px-4 py-2 font-label-caps text-label-caps text-secondary hover:bg-surface-container-high rounded-lg"
              >
                CANCEL
              </button>
              <button
                type="button"
                onClick={handleCreateArea}
                className="px-5 py-2 bg-primary text-on-primary font-label-caps text-label-caps rounded-lg hover:bg-primary-container shadow-sm"
              >
                CREATE GEOFENCE
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
