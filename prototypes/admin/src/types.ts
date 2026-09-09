export type NavPage =
  | 'dashboard'
  | 'employees'
  | 'work-areas'
  | 'attendance'
  | 'leaves'
  | 'reports'
  | 'notifications'
  | 'profile'
  | 'login';

export interface Employee {
  id: string;
  name: string;
  empId: string;
  role: string;
  assignedArea: string;
  schedule: string;
  status: 'Active' | 'Leave' | 'Inactive';
  photoUrl?: string;
  initials?: string;
}

export interface WorkArea {
  id: string;
  name: string;
  areaSqKm: string;
  status: 'Active' | 'Inactive';
  supervisorName: string;
  supervisorPhoto?: string;
  assignedCount: number;
  center?: { lat: number; lng: number };
}

export interface AttendanceLog {
  id: string;
  workerName: string;
  workerId: string;
  initials: string;
  area: string;
  timeIn: string;
  breakIn: string;
  breakOut: string;
  timeOut: string;
  status: 'Verified' | 'Unverified';
  hasWarning?: boolean;
}

export interface LeaveRequest {
  id: string;
  name: string;
  type: 'Sick Leave' | 'Vacation Leave' | 'Emergency';
  district: string;
  crew: string;
  reason: string;
  startDate: string;
  endDate: string;
  duration: string;
  docImage?: string;
  avatarUrl?: string;
  initials?: string;
  status: 'Pending' | 'Approved' | 'Denied';
}

export interface AlertItem {
  id: string;
  type: 'Geofence Breach' | 'Attendance Alert' | 'Score Warning' | 'Overtime Request';
  title: string;
  description: string;
  timeAgo: string;
  severity: 'critical' | 'warning' | 'info';
  workerInfo?: {
    name: string;
    id: string;
    team: string;
    photoUrl?: string;
  };
  expected?: string;
  current?: string;
  score?: number;
}

export interface RecentActivityItem {
  id: string;
  text: string;
  timeAgo: string;
  highlightText?: string;
}

export interface BroadcastNotification {
  id: string;
  recipients: string;
  subject: string;
  body: string;
  timestamp: string;
  deliveredCount: number;
  confidential: boolean;
}

export interface UserProfile {
  name: string;
  email: string;
  role: string;
  department: string;
  avatarUrl: string;
  superAdmin: boolean;
}
