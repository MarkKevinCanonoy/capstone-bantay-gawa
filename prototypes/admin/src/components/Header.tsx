import React from 'react';
import { Search, Menu, Bell, Shield, User } from 'lucide-react';
import { NavPage } from '../types';

interface HeaderProps {
  currentPage: NavPage;
  searchQuery: string;
  onSearchChange: (query: string) => void;
  onOpenMobileMenu: () => void;
  onNavigate: (page: NavPage) => void;
  criticalAlertsCount: number;
}

export const Header: React.FC<HeaderProps> = ({
  currentPage,
  searchQuery,
  onSearchChange,
  onOpenMobileMenu,
  onNavigate,
  criticalAlertsCount,
}) => {
  const getPageTitle = (page: NavPage) => {
    switch (page) {
      case 'dashboard':
        return 'Dashboard Overview';
      case 'employees':
        return 'Employee Management';
      case 'work-areas':
        return 'Work Areas & Geofences';
      case 'attendance':
        return 'Daily Attendance Logs';
      case 'leaves':
        return 'Leave Applications';
      case 'reports':
        return 'Reports & Analytics Engine';
      case 'notifications':
        return 'Communication & Alerts';
      case 'profile':
        return 'Profile Settings';
      case 'login':
        return 'Authentication';
      default:
        return 'Admin Portal';
    }
  };

  return (
    <header className="h-[64px] px-margin-mobile md:px-margin-desktop bg-surface border-b border-outline-variant fixed top-0 right-0 left-0 md:left-[280px] z-30 flex justify-between items-center">
      {/* Left section: Mobile menu toggle + Search */}
      <div className="flex items-center gap-3 flex-1 max-w-md">
        <button
          onClick={onOpenMobileMenu}
          className="md:hidden p-2 text-secondary hover:text-primary transition-colors rounded-lg hover:bg-surface-container-high"
          title="Toggle Menu"
        >
          <Menu className="w-5 h-5" />
        </button>

        <div className="relative w-full max-w-xs md:max-w-md">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-secondary pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder={`Search ${getPageTitle(currentPage).toLowerCase()}...`}
            className="w-full pl-9 pr-4 py-1.5 bg-surface-container-low border border-outline-variant rounded-full text-body-sm font-body-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-secondary-container transition-all"
          />
        </div>
      </div>

      {/* Right section: Title / Quick actions */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => onNavigate('notifications')}
          className="relative p-2 rounded-full hover:bg-surface-container-high text-secondary transition-colors"
          title="View Notifications"
        >
          <Bell className="w-5 h-5" />
          {criticalAlertsCount > 0 && (
            <span className="absolute top-1 right-1 w-2.5 h-2.5 rounded-full bg-error ring-2 ring-surface animate-pulse" />
          )}
        </button>

        <button
          onClick={() => onNavigate('profile')}
          className="hidden sm:flex items-center gap-2 p-1.5 rounded-lg hover:bg-surface-container-high transition-colors text-secondary"
        >
          <User className="w-5 h-5 text-primary" />
        </button>
      </div>
    </header>
  );
};
