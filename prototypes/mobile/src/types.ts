export type NavigationTab = 'home' | 'attendance' | 'map' | 'reports' | 'profile';

export type AttendanceAction = 'Time-In' | 'Break-Out' | 'Break-In' | 'Time-Out';

export interface AttendanceLog {
  id: string;
  action: AttendanceAction;
  timestamp: string; // ISO string or format
  timeFormatted: string;
  zone: string;
  coords: { lat: number; lng: number };
  status: 'Synced' | 'Pending Sync';
  photoUrl?: string;
  method: 'Biometric Face ID' | 'Fallback Selfie' | 'Geofence Auto';
}

export type ReportStatus = 'Approved' | 'Pending' | 'Denied';

export interface AccomplishmentReport {
  id: string;
  title: string;
  date: string;
  time: string;
  details: string;
  status: ReportStatus;
  denialReason?: string;
  photoUrl: string;
  coords: { lat: number; lng: number };
  gpsBurn: string;
}

export type LeaveType = 'Sick Leave' | 'Vacation Leave' | 'Emergency Leave' | 'Other';
export type LeaveStatus = 'Approved' | 'Pending' | 'Denied';

export interface LeaveRequest {
  id: string;
  type: LeaveType;
  startDate: string;
  endDate: string;
  reason: string;
  status: LeaveStatus;
  documentUrl?: string;
  submittedAt: string;
}

export interface WorkerIssueReport {
  id: string;
  workerName: string;
  workerId: string;
  issueType: 'Not working / Loitering' | 'Absent from designated area' | 'Safety violation' | 'Other';
  description: string;
  evidencePhotoUrl?: string;
  timestamp: string;
  coords: { lat: number; lng: number };
  status: 'Under Review' | 'Resolved' | 'Dismissed';
}

export interface PerformanceLog {
  id: string;
  title: string;
  timestamp: string;
  points: number; // e.g. +0.5 or -0.2
  type: 'credit' | 'penalty';
}

export interface WorkerProfile {
  name: string;
  workerId: string;
  qrToken: string;
  qrCodeUrl?: string;
  photoUrl: string;
  assignedArea: string;
  areaCode: string;
  shift: string;
  shiftTime: string;
  performanceScore: number; // e.g. 8.5 out of 10
  verifiedStatus: boolean;
  department: string;
  roleTitle?: string;
}

export interface Announcement {
  id: string;
  title: string;
  body: string;
  postedAt: string;
  priority: 'high' | 'normal';
}

export interface GeofenceZone {
  id: string;
  name: string;
  areaCode: string;
  center: { lat: number; lng: number };
  radiusMeters: number;
}
