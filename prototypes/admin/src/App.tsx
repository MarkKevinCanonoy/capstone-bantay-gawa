import React, { useState } from 'react';
import {
  NavPage,
  Employee,
  WorkArea,
  AttendanceLog,
  LeaveRequest,
  AlertItem,
  RecentActivityItem,
  BroadcastNotification,
  UserProfile,
} from './types';
import {
  initialProfile,
  initialEmployees,
  initialWorkAreas,
  initialAttendanceLogs,
  initialLeaveRequests,
  initialAlerts,
  initialRecentActivity,
  initialBroadcasts,
} from './data/initialData';
import { Sidebar } from './components/Sidebar';
import { Header } from './components/Header';
import { DashboardView } from './components/DashboardView';
import { EmployeesView } from './components/EmployeesView';
import { WorkAreasView } from './components/WorkAreasView';
import { AttendanceView } from './components/AttendanceView';
import { LeavesView } from './components/LeavesView';
import { ReportsView } from './components/ReportsView';
import { NotificationsView } from './components/NotificationsView';
import { ProfileView } from './components/ProfileView';
import { LoginView } from './components/LoginView';
import { ToastContainer, ToastMessage } from './components/Toast';

export default function App() {
  const [currentPage, setCurrentPage] = useState<NavPage>('dashboard');
  const [user, setUser] = useState<UserProfile>(initialProfile);
  const [employees, setEmployees] = useState<Employee[]>(initialEmployees);
  const [workAreas, setWorkAreas] = useState<WorkArea[]>(initialWorkAreas);
  const [attendanceLogs, setAttendanceLogs] = useState<AttendanceLog[]>(initialAttendanceLogs);
  const [leaveRequests, setLeaveRequests] = useState<LeaveRequest[]>(initialLeaveRequests);
  const [alerts, setAlerts] = useState<AlertItem[]>(initialAlerts);
  const [activities, setActivities] = useState<RecentActivityItem[]>(initialRecentActivity);
  const [broadcasts, setBroadcasts] = useState<BroadcastNotification[]>(initialBroadcasts);

  const [toasts, setToasts] = useState<ToastMessage[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false);

  // Toast Trigger Utility
  const triggerToast = (type: 'success' | 'error' | 'info', text: string) => {
    const id = `toast-${Date.now()}-${Math.random()}`;
    setToasts((prev) => [...prev, { id, type, text }]);

    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 3500);
  };

  const handleDismissToast = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  // State Handlers
  const handleAddEmployee = (emp: Employee) => {
    setEmployees((prev) => [emp, ...prev]);
  };

  const handleDeleteEmployee = (id: string) => {
    const target = employees.find((e) => e.id === id);
    setEmployees((prev) => prev.filter((e) => e.id !== id));
    triggerToast('info', `Employee ${target?.name || ''} removed.`);
  };

  const handleUpdateWorkArea = (updated: WorkArea) => {
    setWorkAreas((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
  };

  const handleAddWorkArea = (newArea: WorkArea) => {
    setWorkAreas((prev) => [newArea, ...prev]);
  };

  const handleToggleAttendanceVerify = (id: string) => {
    setAttendanceLogs((prev) =>
      prev.map((log) => {
        if (log.id === id) {
          const nextStatus: 'Verified' | 'Unverified' =
            log.status === 'Verified' ? 'Unverified' : 'Verified';
          return { ...log, status: nextStatus };
        }
        return log;
      })
    );
  };

  const handleUpdateLeaveStatus = (id: string, status: 'Approved' | 'Denied') => {
    setLeaveRequests((prev) =>
      prev.map((req) => (req.id === id ? { ...req, status } : req))
    );
  };

  const handleAddBroadcast = (bc: BroadcastNotification) => {
    setBroadcasts((prev) => [bc, ...prev]);
  };

  const pendingLeavesCount = leaveRequests.filter((r) => r.status === 'Pending').length;
  const criticalAlertsCount = alerts.filter((a) => a.severity === 'critical').length;

  if (currentPage === 'login') {
    return (
      <>
        <LoginView
          onLoginSuccess={() => setCurrentPage('dashboard')}
          onTriggerToast={triggerToast}
        />
        <ToastContainer toasts={toasts} onDismiss={handleDismissToast} />
      </>
    );
  }

  return (
    <div className="bg-background text-on-background min-h-screen font-body-md antialiased flex flex-col">
      {/* Sidebar Navigation */}
      <Sidebar
        currentPage={currentPage}
        onNavigate={setCurrentPage}
        user={user}
        pendingLeavesCount={pendingLeavesCount}
        criticalAlertsCount={criticalAlertsCount}
        mobileOpen={mobileSidebarOpen}
        onCloseMobile={() => setMobileSidebarOpen(false)}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col md:ml-[280px]">
        {/* Top Header Bar */}
        <Header
          currentPage={currentPage}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          onOpenMobileMenu={() => setMobileSidebarOpen(true)}
          onNavigate={setCurrentPage}
          criticalAlertsCount={criticalAlertsCount}
        />

        {/* View Canvas */}
        <main className="flex-1 pt-[84px] px-margin-mobile md:px-margin-desktop pb-12">
          {currentPage === 'dashboard' && (
            <DashboardView
              onNavigate={setCurrentPage}
              alerts={alerts}
              activities={activities}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'employees' && (
            <EmployeesView
              employees={employees}
              onAddEmployee={handleAddEmployee}
              onDeleteEmployee={handleDeleteEmployee}
              searchQuery={searchQuery}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'work-areas' && (
            <WorkAreasView
              workAreas={workAreas}
              onUpdateWorkArea={handleUpdateWorkArea}
              onAddWorkArea={handleAddWorkArea}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'attendance' && (
            <AttendanceView
              logs={attendanceLogs}
              onToggleVerify={handleToggleAttendanceVerify}
              searchQuery={searchQuery}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'leaves' && (
            <LeavesView
              leaveRequests={leaveRequests}
              onUpdateLeaveStatus={handleUpdateLeaveStatus}
              searchQuery={searchQuery}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'reports' && (
            <ReportsView onTriggerToast={triggerToast} />
          )}

          {currentPage === 'notifications' && (
            <NotificationsView
              alerts={alerts}
              broadcasts={broadcasts}
              onAddBroadcast={handleAddBroadcast}
              onNavigate={setCurrentPage}
              onTriggerToast={triggerToast}
            />
          )}

          {currentPage === 'profile' && (
            <ProfileView
              user={user}
              onUpdateProfile={setUser}
              onNavigate={setCurrentPage}
              onTriggerToast={triggerToast}
            />
          )}
        </main>
      </div>

      {/* Global Toast Container */}
      <ToastContainer toasts={toasts} onDismiss={handleDismissToast} />
    </div>
  );
}
