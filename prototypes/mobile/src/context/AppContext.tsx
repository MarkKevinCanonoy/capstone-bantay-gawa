import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  NavigationTab,
  WorkerProfile,
  AttendanceLog,
  AccomplishmentReport,
  LeaveRequest,
  WorkerIssueReport,
  PerformanceLog,
  Announcement,
  GeofenceZone
} from '../types';

interface AppContextType {
  currentTab: NavigationTab;
  setCurrentTab: (tab: NavigationTab) => void;
  isOffline: boolean;
  setIsOffline: (offline: boolean) => void;
  pendingSyncCount: number;
  isAuthenticated: boolean;
  language: 'ph' | 'en';
  setLanguage: (lang: 'ph' | 'en') => void;
  profile: WorkerProfile;
  demoWorkers: WorkerProfile[];
  loginWithWorker: (worker: WorkerProfile) => void;
  loginWithQrToken: (qrToken: string) => WorkerProfile | null;
  logout: () => void;
  attendanceLogs: AttendanceLog[];
  accomplishmentReports: AccomplishmentReport[];
  leaveRequests: LeaveRequest[];
  issueReports: WorkerIssueReport[];
  performanceLogs: PerformanceLog[];
  announcements: Announcement[];
  geofenceZones: GeofenceZone[];
  currentZone: GeofenceZone;
  isInsideGeofence: boolean;
  setIsInsideGeofence: (inside: boolean) => void;
  userCoords: { lat: number; lng: number };
  setUserCoords: (coords: { lat: number; lng: number }) => void;
  // Actions
  addAttendanceLog: (action: AttendanceLog['action'], method?: AttendanceLog['method'], photoUrl?: string) => void;
  addAccomplishmentReport: (title: string, details: string, photoUrl: string) => void;
  addLeaveRequest: (type: LeaveRequest['type'], startDate: string, endDate: string, reason: string, docUrl?: string) => void;
  addWorkerIssueReport: (workerName: string, workerId: string, issueType: WorkerIssueReport['issueType'], description: string, evidencePhotoUrl?: string) => void;
  syncData: () => void;
  activeAttendanceAction: 'Time-In' | 'Break-Out' | 'Break-In' | 'Time-Out' | 'None';
  showLeaveModal: boolean;
  setShowLeaveModal: (show: boolean) => void;
  showIssueReportModal: boolean;
  setShowIssueReportModal: (show: boolean) => void;
}

export const DEMO_WORKERS: WorkerProfile[] = [
  {
    name: 'Juan Dela Cruz',
    workerId: '2024-001',
    qrToken: 'QR-LGU-2024-001',
    photoUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?q=80&w=400&auto=format&fit=crop',
    roleTitle: 'Heavy Drainage Maintenance Lead',
    assignedArea: 'Area 5 - North Dist.',
    areaCode: 'DWTN-04',
    shift: 'Morning Shift',
    shiftTime: '06:00 AM - 02:00 PM',
    performanceScore: 8.5,
    verifiedStatus: true,
    department: 'LGU Public Works & Engineering'
  },
  {
    name: 'Maria Santos',
    workerId: '2024-042',
    qrToken: 'QR-LGU-2024-042',
    photoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=400&auto=format&fit=crop',
    roleTitle: 'Barangay Health & Sanitation Inspector',
    assignedArea: 'Sector 4 - Plaza Zone',
    areaCode: 'PLZA-02',
    shift: 'Day Shift',
    shiftTime: '07:00 AM - 03:00 PM',
    performanceScore: 9.2,
    verifiedStatus: true,
    department: 'LGU Health & Sanitation'
  },
  {
    name: 'Antonio Reyes',
    workerId: '2024-089',
    qrToken: 'QR-LGU-2024-089',
    photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=400&auto=format&fit=crop',
    roleTitle: 'Traffic Enforcement & Safety Officer',
    assignedArea: 'Avenue Cor. Central',
    areaCode: 'TRFF-08',
    shift: 'Evening Shift',
    shiftTime: '02:00 PM - 10:00 PM',
    performanceScore: 8.8,
    verifiedStatus: true,
    department: 'LGU Traffic & Public Safety'
  },
  {
    name: 'Elena Garcia',
    workerId: '2024-105',
    qrToken: 'QR-LGU-2024-105',
    photoUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=400&auto=format&fit=crop',
    roleTitle: 'Street Sweeper & Parks Team Lead',
    assignedArea: 'Sector 1 - City Park',
    areaCode: 'PARK-01',
    shift: 'Early Morning Shift',
    shiftTime: '05:00 AM - 01:00 PM',
    performanceScore: 9.5,
    verifiedStatus: true,
    department: 'LGU Environment & Cleanliness'
  }
];

const getTodayTimeInLog = (): AttendanceLog => {
  const now = new Date();
  return {
    id: 'att-today-1',
    action: 'Time-In',
    timestamp: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 6, 2, 0).toISOString(),
    timeFormatted: 'Today, 06:02 AM',
    zone: 'Sector 4 - Downtown Zone',
    coords: { lat: 14.5995, lng: 120.9842 },
    status: 'Synced',
    method: 'Biometric Face ID'
  };
};

const initialAttendanceLogs: AttendanceLog[] = [
  getTodayTimeInLog(),
  {
    id: 'att-yesterday-1',
    action: 'Time-In',
    timestamp: new Date(Date.now() - 86400000).toISOString(),
    timeFormatted: 'Yesterday, 06:00 AM',
    zone: 'Sector 4 - Downtown Zone',
    coords: { lat: 14.5995, lng: 120.9842 },
    status: 'Synced',
    method: 'Biometric Face ID'
  },
  {
    id: 'att-yesterday-2',
    action: 'Time-Out',
    timestamp: new Date(Date.now() - 86400000).toISOString(),
    timeFormatted: 'Yesterday, 02:05 PM',
    zone: 'Sector 4 - Downtown Zone',
    coords: { lat: 14.5995, lng: 120.9842 },
    status: 'Synced',
    method: 'Biometric Face ID'
  }
];

const initialAccomplishmentReports: AccomplishmentReport[] = [
  {
    id: 'rep-1',
    title: 'Drainage Inspection',
    date: 'Oct 27, 2023',
    time: '09:15 PST',
    details: 'Completed physical inspection of main culverts near Sector 4 plaza. Cleared minor debris.',
    status: 'Pending',
    photoUrl: 'https://images.unsplash.com/photo-1541888946425-d0fbb186a5b3?q=80&w=600&auto=format&fit=crop',
    coords: { lat: 14.5995, lng: 120.9842 },
    gpsBurn: 'LAT: 14.5995 | LNG: 120.9842 | 2023-10-27 09:15:00 PST'
  },
  {
    id: 'rep-2',
    title: 'Road Clearing - Zone A',
    date: 'Oct 26, 2023',
    time: '16:00 PST',
    details: 'Removed fallen branches and hazards following afternoon torrential storm.',
    status: 'Approved',
    photoUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?q=80&w=600&auto=format&fit=crop',
    coords: { lat: 14.5971, lng: 120.9811 },
    gpsBurn: 'LAT: 14.5971 | LNG: 120.9811 | 2023-10-26 16:00:12 PST'
  },
  {
    id: 'rep-3',
    title: 'Equipment Audit',
    date: 'Oct 25, 2023',
    time: '11:30 PST',
    details: 'Standard field inventory check on safety gear and heavy tools.',
    status: 'Denied',
    denialReason: 'Photo proof blurred. Please resubmit with clear GPS burn.',
    photoUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?q=80&w=600&auto=format&fit=crop',
    coords: { lat: 14.598, lng: 120.983 },
    gpsBurn: 'LAT: 14.5980 | LNG: 120.9830 | 2023-10-25 11:30:45 PST'
  }
];

const initialLeaveRequests: LeaveRequest[] = [
  {
    id: 'leave-1',
    type: 'Sick Leave',
    startDate: '2023-10-12',
    endDate: '2023-10-13',
    reason: 'Severe flu and high fever with medical advisory to rest.',
    status: 'Approved',
    submittedAt: 'Oct 11, 2023'
  },
  {
    id: 'leave-2',
    type: 'Emergency Leave',
    startDate: '2023-11-05',
    endDate: '2023-11-05',
    reason: 'Family emergency requiring immediate attention at provincial hospital.',
    status: 'Pending',
    submittedAt: 'Nov 04, 2023'
  }
];

const initialPerformanceLogs: PerformanceLog[] = [
  {
    id: 'perf-1',
    title: 'Task completed early',
    timestamp: 'OCT 14, 2024 - 14:30',
    points: 0.5,
    type: 'credit'
  },
  {
    id: 'perf-2',
    title: 'Late clock-in',
    timestamp: 'OCT 12, 2024 - 08:15',
    points: -0.2,
    type: 'penalty'
  }
];

const initialAnnouncements: Announcement[] = [
  {
    id: 'ann-1',
    title: 'Mandatory Safety Briefing Tomorrow',
    body: 'All LGU field personnel must report to Sector 4 Command Post at 07:00 AM sharp for safety protocol updates.',
    postedAt: 'Today, 08:00 AM',
    priority: 'high'
  },
  {
    id: 'ann-2',
    title: 'Typhoon Weather Advisory - Zone 4',
    body: 'Ensure all high-visibility vests and waterproof GPS loggers are fully charged.',
    postedAt: 'Yesterday, 04:30 PM',
    priority: 'normal'
  }
];

const initialZones: GeofenceZone[] = [
  {
    id: 'zone-1',
    name: 'Sector 4 - Downtown Zone',
    areaCode: 'DWTN-04',
    center: { lat: 14.5995, lng: 120.9842 },
    radiusMeters: 300
  },
  {
    id: 'zone-2',
    name: 'Area 5 - North District',
    areaCode: 'NRTH-05',
    center: { lat: 14.605, lng: 120.989 },
    radiusMeters: 450
  },
  {
    id: 'zone-3',
    name: 'Sector 2 - West Plaza',
    areaCode: 'PLZA-02',
    center: { lat: 14.591, lng: 120.978 },
    radiusMeters: 250
  }
];

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentTab, setCurrentTab] = useState<NavigationTab>('home');
  const [isOffline, setIsOffline] = useState<boolean>(false);
  const [language, setLanguage] = useState<'ph' | 'en'>('ph');

  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    const savedAuth = localStorage.getItem('bantaygawa_authenticated');
    return savedAuth ? JSON.parse(savedAuth) : false;
  });

  const [profile, setProfile] = useState<WorkerProfile>(() => {
    const saved = localStorage.getItem('bantaygawa_profile');
    return saved ? JSON.parse(saved) : DEMO_WORKERS[0];
  });

  const [attendanceLogs, setAttendanceLogs] = useState<AttendanceLog[]>(() => {
    const saved = localStorage.getItem('bantaygawa_attendance_v4');
    if (saved) {
      try {
        const parsed: AttendanceLog[] = JSON.parse(saved);
        const todayDateStr = new Date().toDateString();
        const hasTodayLog = parsed.some((l) => {
          try {
            return new Date(l.timestamp).toDateString() === todayDateStr;
          } catch {
            return false;
          }
        });
        if (hasTodayLog) return parsed;
        return [getTodayTimeInLog(), ...parsed];
      } catch {
        return initialAttendanceLogs;
      }
    }
    return initialAttendanceLogs;
  });
  const [accomplishmentReports, setAccomplishmentReports] = useState<AccomplishmentReport[]>(() => {
    const saved = localStorage.getItem('bantaygawa_reports');
    return saved ? JSON.parse(saved) : initialAccomplishmentReports;
  });
  const [leaveRequests, setLeaveRequests] = useState<LeaveRequest[]>(() => {
    const saved = localStorage.getItem('bantaygawa_leaves');
    return saved ? JSON.parse(saved) : initialLeaveRequests;
  });
  const [issueReports, setIssueReports] = useState<WorkerIssueReport[]>(() => {
    const saved = localStorage.getItem('bantaygawa_issues');
    return saved ? JSON.parse(saved) : [];
  });
  const [performanceLogs] = useState<PerformanceLog[]>(initialPerformanceLogs);
  const [announcements] = useState<Announcement[]>(initialAnnouncements);
  const [geofenceZones] = useState<GeofenceZone[]>(initialZones);
  const [currentZone] = useState<GeofenceZone>(initialZones[0]);
  const [isInsideGeofence, setIsInsideGeofence] = useState<boolean>(true);
  const [userCoords, setUserCoords] = useState<{ lat: number; lng: number }>({ lat: 14.5995, lng: 120.9842 });
  const [showLeaveModal, setShowLeaveModal] = useState<boolean>(false);
  const [showIssueReportModal, setShowIssueReportModal] = useState<boolean>(false);

  // Save changes to localStorage
  useEffect(() => {
    localStorage.setItem('bantaygawa_authenticated', JSON.stringify(isAuthenticated));
  }, [isAuthenticated]);

  useEffect(() => {
    localStorage.setItem('bantaygawa_profile', JSON.stringify(profile));
  }, [profile]);

  useEffect(() => {
    localStorage.setItem('bantaygawa_attendance_v4', JSON.stringify(attendanceLogs));
  }, [attendanceLogs]);

  useEffect(() => {
    localStorage.setItem('bantaygawa_reports', JSON.stringify(accomplishmentReports));
  }, [accomplishmentReports]);

  useEffect(() => {
    localStorage.setItem('bantaygawa_leaves', JSON.stringify(leaveRequests));
  }, [leaveRequests]);

  useEffect(() => {
    localStorage.setItem('bantaygawa_issues', JSON.stringify(issueReports));
  }, [issueReports]);

  const loginWithWorker = (worker: WorkerProfile) => {
    setProfile(worker);
    setIsAuthenticated(true);
  };

  const loginWithQrToken = (qrToken: string): WorkerProfile | null => {
    // Look up worker by QR token or ID or match default
    const matched = DEMO_WORKERS.find(
      w => w.qrToken.toLowerCase() === qrToken.toLowerCase() ||
           w.workerId.toLowerCase() === qrToken.toLowerCase()
    );
    if (matched) {
      setProfile(matched);
      setIsAuthenticated(true);
      return matched;
    } else {
      // Fallback: create tokenized profile if unknown QR token scanned
      const newWorker: WorkerProfile = {
        name: 'Worker ' + qrToken.substring(0, 6).toUpperCase(),
        workerId: 'ID-' + Math.floor(1000 + Math.random() * 9000),
        qrToken: qrToken,
        photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=400&auto=format&fit=crop',
        roleTitle: 'LGU Field Operator',
        assignedArea: 'Sector 4 - Plaza Zone',
        areaCode: 'DWTN-04',
        shift: 'Day Shift',
        shiftTime: '07:00 AM - 03:00 PM',
        performanceScore: 9.0,
        verifiedStatus: true,
        department: 'LGU Field Operations'
      };
      setProfile(newWorker);
      setIsAuthenticated(true);
      return newWorker;
    }
  };

  const logout = () => {
    setIsAuthenticated(false);
  };

  // Derived state for pending sync items
  const pendingSyncCount = 
    attendanceLogs.filter(l => l.status === 'Pending Sync').length +
    accomplishmentReports.filter(r => r.status === 'Pending' && isOffline).length;

  const activeAttendanceAction = (() => {
    if (attendanceLogs.length === 0) return 'None';
    const last = attendanceLogs[0]; // sorted newest first
    if (last.action === 'Time-In' || last.action === 'Break-In') return 'Time-In';
    if (last.action === 'Break-Out') return 'Break-Out';
    return 'None';
  })();

  const addAttendanceLog = (
    action: AttendanceLog['action'],
    method: AttendanceLog['method'] = 'Biometric Face ID',
    photoUrl?: string
  ) => {
    const now = new Date();
    const timeFormatted = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
    const newLog: AttendanceLog = {
      id: `att-${Date.now()}`,
      action,
      timestamp: now.toISOString(),
      timeFormatted,
      zone: currentZone.name,
      coords: userCoords,
      status: isOffline ? 'Pending Sync' : 'Synced',
      method,
      photoUrl
    };
    setAttendanceLogs(prev => [newLog, ...prev]);
  };

  const addAccomplishmentReport = (title: string, details: string, photoUrl: string) => {
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    const timeStr = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) + ' PST';
    const newReport: AccomplishmentReport = {
      id: `rep-${Date.now()}`,
      title,
      date: dateStr,
      time: timeStr,
      details,
      status: 'Pending',
      photoUrl,
      coords: userCoords,
      gpsBurn: `LAT: ${userCoords.lat.toFixed(4)} | LNG: ${userCoords.lng.toFixed(4)} | ${now.toISOString().replace('T', ' ').substring(0, 19)} PST`
    };
    setAccomplishmentReports(prev => [newReport, ...prev]);
  };

  const addLeaveRequest = (type: LeaveRequest['type'], startDate: string, endDate: string, reason: string, docUrl?: string) => {
    const now = new Date();
    const newLeave: LeaveRequest = {
      id: `leave-${Date.now()}`,
      type,
      startDate,
      endDate,
      reason,
      status: 'Pending',
      submittedAt: now.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
      documentUrl: docUrl
    };
    setLeaveRequests(prev => [newLeave, ...prev]);
  };

  const addWorkerIssueReport = (
    workerName: string,
    workerId: string,
    issueType: WorkerIssueReport['issueType'],
    description: string,
    evidencePhotoUrl?: string
  ) => {
    const newIssue: WorkerIssueReport = {
      id: `issue-${Date.now()}`,
      workerName,
      workerId,
      issueType,
      description,
      evidencePhotoUrl,
      timestamp: new Date().toLocaleString(),
      coords: userCoords,
      status: 'Under Review'
    };
    setIssueReports(prev => [newIssue, ...prev]);
  };

  const syncData = () => {
    setAttendanceLogs(prev =>
      prev.map(l => (l.status === 'Pending Sync' ? { ...l, status: 'Synced' } : l))
    );
  };

  return (
    <AppContext.Provider
      value={{
        currentTab,
        setCurrentTab,
        isOffline,
        setIsOffline,
        pendingSyncCount,
        isAuthenticated,
        language,
        setLanguage,
        profile,
        demoWorkers: DEMO_WORKERS,
        loginWithWorker,
        loginWithQrToken,
        logout,
        attendanceLogs,
        accomplishmentReports,
        leaveRequests,
        issueReports,
        performanceLogs,
        announcements,
        geofenceZones,
        currentZone,
        isInsideGeofence,
        setIsInsideGeofence,
        userCoords,
        setUserCoords,
        addAttendanceLog,
        addAccomplishmentReport,
        addLeaveRequest,
        addWorkerIssueReport,
        syncData,
        activeAttendanceAction,
        showLeaveModal,
        setShowLeaveModal,
        showIssueReportModal,
        setShowIssueReportModal
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
};
