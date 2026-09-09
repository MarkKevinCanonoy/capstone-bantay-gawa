import React from 'react';
import { NavPage, UserProfile } from '../types';
import { X, LogOut, MoreVertical } from 'lucide-react';

interface SidebarProps {
  currentPage: NavPage;
  onNavigate: (page: NavPage) => void;
  user: UserProfile;
  pendingLeavesCount: number;
  criticalAlertsCount: number;
  mobileOpen: boolean;
  onCloseMobile: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentPage,
  onNavigate,
  user,
  pendingLeavesCount,
  criticalAlertsCount,
  mobileOpen,
  onCloseMobile,
}) => {
  const navItems: { page: NavPage; label: string; icon: string; badge?: number }[] = [
    { page: 'dashboard', label: 'Dashboard', icon: 'dashboard' },
    { page: 'employees', label: 'Employees', icon: 'badge' },
    { page: 'work-areas', label: 'Work Areas', icon: 'map' },
    { page: 'attendance', label: 'Attendance', icon: 'event_available' },
    { page: 'leaves', label: 'Leaves', icon: 'calendar_today', badge: pendingLeavesCount },
    { page: 'reports', label: 'Reports', icon: 'analytics' },
    { page: 'notifications', label: 'Notifications', icon: 'notifications', badge: criticalAlertsCount },
  ];

  const sidebarContent = (
    <div className="flex flex-col h-full bg-surface-container-lowest border-r border-outline-variant py-gutter w-[280px]">
      {/* Brand Header */}
      <div className="px-gutter mb-6 flex justify-between items-center">
        <div>
          <h1 className="font-headline-md text-headline-md font-bold text-primary tracking-tight">
            BantayGawaMobile
          </h1>
          <p className="font-body-sm text-body-sm text-secondary">Admin Portal</p>
        </div>
        {mobileOpen && (
          <button
            onClick={onCloseMobile}
            className="md:hidden p-1.5 rounded-lg hover:bg-surface-container-high text-secondary"
          >
            <X className="w-5 h-5" />
          </button>
        )}
      </div>

      {/* Nav List */}
      <nav className="flex-1 px-4 space-y-1 overflow-y-auto">
        {navItems.map((item) => {
          const isActive = currentPage === item.page;
          return (
            <button
              key={item.page}
              onClick={() => {
                onNavigate(item.page);
                if (mobileOpen) onCloseMobile();
              }}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-body-md text-body-md transition-all text-left ${
                isActive
                  ? 'text-primary font-bold bg-surface-container-low border-r-4 border-primary'
                  : 'text-secondary font-medium hover:bg-surface-container-high'
              }`}
            >
              <span
                className="material-symbols-outlined text-[20px]"
                style={isActive ? { fontVariationSettings: "'FILL' 1" } : undefined}
              >
                {item.icon}
              </span>
              <span className="flex-1 truncate">{item.label}</span>
              {item.badge !== undefined && item.badge > 0 && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-error-container text-on-error-container">
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Bottom Profile Footer */}
      <div className="mt-auto px-4 pt-4 border-t border-outline-variant">
        <div
          onClick={() => {
            onNavigate('profile');
            if (mobileOpen) onCloseMobile();
          }}
          className="flex items-center gap-3 p-2 rounded-lg hover:bg-surface-container-high transition-colors cursor-pointer group"
        >
          <img
            src={user.avatarUrl}
            alt={user.name}
            className="w-10 h-10 rounded-full border border-outline-variant object-cover shrink-0"
          />
          <div className="flex-1 min-w-0">
            <p className="font-title-sm text-[14px] text-on-surface truncate font-semibold">
              {user.name}
            </p>
            <p className="font-body-sm text-[12px] text-secondary truncate">{user.role}</p>
          </div>

          <button
            title="Log Out"
            onClick={(e) => {
              e.stopPropagation();
              onNavigate('login');
              if (mobileOpen) onCloseMobile();
            }}
            className="p-1 text-secondary hover:text-error transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop Sidebar */}
      <aside className="hidden md:block fixed left-0 top-0 bottom-0 z-40 w-[280px]">
        {sidebarContent}
      </aside>

      {/* Mobile Drawer Overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div
            className="fixed inset-0 bg-black/40 backdrop-blur-xs"
            onClick={onCloseMobile}
          />
          <div className="fixed inset-y-0 left-0 z-50 w-[280px] shadow-2xl">
            {sidebarContent}
          </div>
        </div>
      )}
    </>
  );
};
