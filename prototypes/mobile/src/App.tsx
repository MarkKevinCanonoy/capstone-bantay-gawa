import React from 'react';
import { AppProvider, useApp } from './context/AppContext';
import { Header } from './components/Header';
import { OfflineBanner } from './components/OfflineBanner';
import { BottomNav } from './components/BottomNav';
import { HomeView } from './views/HomeView';
import { AttendanceView } from './views/AttendanceView';
import { MapView } from './views/MapView';
import { ReportsView } from './views/ReportsView';
import { ProfileView } from './views/ProfileView';
import { LoginView } from './views/LoginView';
import { LeaveRequestModal } from './components/LeaveRequestModal';
import { WorkerIssueReportModal } from './components/WorkerIssueReportModal';

const AppContent: React.FC = () => {
  const { isAuthenticated, currentTab, isOffline, pendingSyncCount } = useApp();

  if (!isAuthenticated) {
    return <LoginView />;
  }

  return (
    <div className="bg-[#faf9fd] text-[#1a1c1e] min-h-screen font-sans antialiased flex flex-col selection:bg-[#1a365d] selection:text-white">
      {/* Top Header */}
      <Header />

      {/* Offline Mode Sync Banner */}
      <OfflineBanner />

      {/* Main View Container */}
      <main className={`flex-1 px-4 w-full transition-all ${
        isOffline || pendingSyncCount > 0 ? 'pt-[88px]' : 'pt-[60px]'
      }`}>
        {currentTab === 'home' && <HomeView />}
        {currentTab === 'attendance' && <AttendanceView />}
        {currentTab === 'map' && <MapView />}
        {currentTab === 'reports' && <ReportsView />}
        {currentTab === 'profile' && <ProfileView />}
      </main>

      {/* Global Modals */}
      <LeaveRequestModal />
      <WorkerIssueReportModal />

      {/* Fixed Bottom Navigation */}
      <BottomNav />
    </div>
  );
};

export default function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}
