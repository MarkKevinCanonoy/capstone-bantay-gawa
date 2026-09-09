import {
  Employee,
  WorkArea,
  AttendanceLog,
  LeaveRequest,
  AlertItem,
  RecentActivityItem,
  BroadcastNotification,
  UserProfile,
} from '../types';

export const initialProfile: UserProfile = {
  name: 'Juan Dela Cruz',
  email: 'juan.delacruz@lgu.gov',
  role: 'System Administrator',
  department: 'IT Department',
  avatarUrl:
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAvPvGOuSoxsJVorExO5lDOmOlsRizo0nmGOo8nU5hJbrXZHPfvwtkFQcNfTZ_ZvkDdgRdWYdrSGeAlZzCyUuPZ56bCciVCDTlWXpfXYu7fmKx7Tuw27pA0WVKV_yVRT6XtvI49N1ZiUqB3_x153MTLv5HiqYRuDc81pKKnkL58GJRq_RxfLye6lVAC_qbzQkSTw__DSmAYz8A2vDDFfEL68Sl8Lo2yUGtqw3y8O1UjnNn4oK6sRdtA2XhUaMEmQpi0-m-xwrlxODXP',
  superAdmin: true,
};

export const initialEmployees: Employee[] = [
  {
    id: 'emp-1',
    name: 'Juan Dela Cruz',
    empId: 'EMP-2023-001',
    role: 'Field Inspector',
    assignedArea: 'North District, Zone 1',
    schedule: '08:00 AM - 05:00 PM',
    status: 'Active',
    photoUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBDyiYRlliBi1gnCEXOXBhmAMsouFNwoVTtZHtH_e-8wh6n5s9RnOqVNQ44TJf0GO1DNgmDEn3ZiUCim81B9Vks8MkKgeaPfTafxk_KjuYj9lbbpPrm1LC_Z3_2J1uSyZoUsUeTUSsDkoKv7L84v00ctdj69yIj3HbZDoP9GiGIdwOjA-UrBI-6FOmPwmFqMuwx4-MM_k0ijtN4DHKgRVtGykG9UfrzPNk3B6Jx256K7dIb8W7_boY532TkhILvD8pfYNVHcy2jIl8u',
  },
  {
    id: 'emp-2',
    name: 'Maria Santos',
    empId: 'EMP-2023-042',
    role: 'Admin Assistant',
    assignedArea: 'City Hall, Level 2',
    schedule: '09:00 AM - 06:00 PM',
    status: 'Active',
    initials: 'MS',
  },
  {
    id: 'emp-3',
    name: 'Roberto Reyes',
    empId: 'EMP-2022-118',
    role: 'Security Personnel',
    assignedArea: 'South Gate',
    schedule: '06:00 PM - 06:00 AM',
    status: 'Leave',
    photoUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCiT-2T3kvTsnudHoCf5BD8-3UxjB1v_zny9zJld1T2EhjnqY2zFPzAiNmsvrykUhNoQ6xS4mIitl_V1_FTwJAmptEF3TJU562T2yoqmR8J-XaW3KNektA2bfztAKzTQzkUSS4gi_RCmEJRdhUY7wa3k2CtCI6-aO-U5cnH65ajxNBYH7Av1OA7UU-Z4klRvWlwF0hmXmmIXh0Dihn4YxDTxq09C3om69bNsrGY_xopSosWZefKzCFieJE-mnT8uGhBIA6HeyCIva85',
  },
  {
    id: 'emp-4',
    name: 'Sarah Jenkins',
    empId: 'EMP-2023-8422',
    role: 'Field Supervisor',
    assignedArea: 'East Side Residential',
    schedule: '08:00 AM - 05:00 PM',
    status: 'Active',
    photoUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBwLZZF3ncjWpdvooi_EgLT--vq-DtgqyZaTKJmhhvnTJ6Dw_oOAktOI3iGEyiCneAuFFDSWRmPbSHVm5GSwbMkEJ8RMYOmEuawnr3sT_WlX99CQL13XxuGncc0xoy9gTgzUlo1fAWZrikpCGU-DYX3quNYTUnMC8GZbFuTxUkwboSqqAcpkygaSWreNo0TSHItIgJy5Uij7erSEmk5nRjx4pEqnPXljw4Ohrp87fD6E23E8i4SVfLf_hV092zIMDo2hThTFgaosxAZ',
  },
  {
    id: 'emp-5',
    name: 'Pedro Torres',
    empId: 'EMP-2021-0955',
    role: 'Maintenance Technician',
    assignedArea: 'South Harbor Dock',
    schedule: '07:30 AM - 04:30 PM',
    status: 'Active',
    initials: 'PT',
  },
];

export const initialWorkAreas: WorkArea[] = [
  {
    id: 'area-1',
    name: 'Sector 4 - Commercial',
    areaSqKm: '4.2 sq km',
    status: 'Active',
    supervisorName: 'J. Reyes',
    supervisorPhoto:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDdy5oE5FwCLc8Hc2aq06dvqNefB0LFFkoe-t0WmP6j8xKEAdGNb9MQ9J5jAqzB0eu1fSAwe6rne6PkPXwEwyNb_yshNicZerHyREAqB5I7ImiyquxFBnjwpEoE3eAaEsrJH3Cs8pvp8Botd8cFlbgxnYLXQ5GBj4Q_yM3x2am_wxJ0RZ4GW-1kLgOZTaKpAEEsMpKuaHamxDL06YKT-SFF3gAJcZSPftHDOG2Aee3AGCh-zseeK63tFeXXCbb2cxSnBAN7ahXBiiLP',
    assignedCount: 12,
  },
  {
    id: 'area-2',
    name: 'Sector 2 - Residential',
    areaSqKm: '1.8 sq km',
    status: 'Inactive',
    supervisorName: 'Unassigned',
    assignedCount: 0,
  },
  {
    id: 'area-3',
    name: 'Downtown Sector A',
    areaSqKm: '3.1 sq km',
    status: 'Active',
    supervisorName: 'M. Santos',
    assignedCount: 145,
  },
  {
    id: 'area-4',
    name: 'North Industrial Park',
    areaSqKm: '5.6 sq km',
    status: 'Active',
    supervisorName: 'R. Reyes',
    assignedCount: 89,
  },
  {
    id: 'area-5',
    name: 'East Side Residential',
    areaSqKm: '2.9 sq km',
    status: 'Active',
    supervisorName: 'S. Jenkins',
    assignedCount: 210,
  },
  {
    id: 'area-6',
    name: 'South Harbor Dock',
    areaSqKm: '6.0 sq km',
    status: 'Active',
    supervisorName: 'P. Torres',
    assignedCount: 340,
  },
];

export const initialAttendanceLogs: AttendanceLog[] = [
  {
    id: 'log-1',
    workerName: 'Maria Cruz',
    workerId: '1042',
    initials: 'MC',
    area: 'Zone Alpha',
    timeIn: '07:55 AM',
    breakIn: '12:05 PM',
    breakOut: '01:00 PM',
    timeOut: '05:05 PM',
    status: 'Verified',
  },
  {
    id: 'log-2',
    workerName: 'Juan Dela Cruz',
    workerId: '1088',
    initials: 'JD',
    area: 'Sector 4',
    timeIn: '08:45 AM',
    breakIn: '--:-- --',
    breakOut: '--:-- --',
    timeOut: '--:-- --',
    status: 'Unverified',
    hasWarning: true,
  },
  {
    id: 'log-3',
    workerName: 'Ana Santos',
    workerId: '1102',
    initials: 'AS',
    area: 'Central Plaza',
    timeIn: '07:58 AM',
    breakIn: '12:00 PM',
    breakOut: '12:55 PM',
    timeOut: '--:-- --',
    status: 'Verified',
  },
  {
    id: 'log-4',
    workerName: 'Pedro Torres',
    workerId: '0955',
    initials: 'PT',
    area: 'North Bridge',
    timeIn: '08:02 AM',
    breakIn: '12:15 PM',
    breakOut: '01:10 PM',
    timeOut: 'Missing',
    status: 'Unverified',
    hasWarning: true,
  },
];

export const initialLeaveRequests: LeaveRequest[] = [
  {
    id: 'leave-1',
    name: 'Juan Dela Cruz',
    type: 'Sick Leave',
    district: 'North District',
    crew: 'Maintenance Crew',
    reason: 'Experiencing flu symptoms. Requesting time off to rest and recover. Attached medical certificate.',
    startDate: 'Oct 12, 2023',
    endDate: 'Oct 14, 2023',
    duration: '3 Days',
    avatarUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDZBxv2r4xcA6NKPyE62lX1iuTyI7ox5g-NASlWl1frdZgd8hKgN2YJMnekTXscIK4Bj9d5gY7Rj_mjNRkzld2R1wi6833i5fAyH7sdwZq1Cdt2IPh-F_HjDuf6NwTtjTPkeFHBRPyEeTS8FiXlW0tB_R-KV8vjEcoDL-zk4PQZ_kHkZ3kt3-2Qi4zzPCKuZNyIB8lsRbMqrZ3HgWWUimopCqlnr6cuT3Vi8EkR98l6kWFpHR8_r1W3GahSjiRkg24blIDQSPud_tEu',
    docImage:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBOYKDbM_ZNhKpSWHfIkt4r9pDRKDwJ05LF-85vT4-3zu0oCS-Z-POneWziD6U0UVEmwfRhgVw4Cimcb8tpOmxJ9Dy1ZPbgVediicvB9eLk-ud6FuYej26GUazVAtPYgm1p0rLOAMztR5B_vKoDWpGyWxS1r16rz96VnVp0IG8rQ2uCBntQ11rfg80F5qDzL2RKq3iyoMVZWgj3LsM3lap1G0EfMufAHdKoxJfgOVeJkQvkK4PbD6i7Zr7sybBgx-yBewDASI95gKCe',
    status: 'Pending',
  },
  {
    id: 'leave-2',
    name: 'Maria Santos',
    type: 'Vacation Leave',
    district: 'South District',
    crew: 'Inspection Team',
    reason: 'Annual family vacation. All current projects handed over to team lead.',
    startDate: 'Nov 01, 2023',
    endDate: 'Nov 05, 2023',
    duration: '5 Days',
    avatarUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAcINi9hsYh3iN7hSVBDoSKstpurGVEa-4r9NYS4YtM1QGqDXOWMiwLcs-YvDPC_h5kIteoP8M88yGul0QdyyI4weFbsDl46fkCHb-wmI1hufr4TVygBdlHxiEKCKxbVPv7MFwa6KM3eNLjVVeM0KBBpXDZtEDLAXTXRZKw8Oz39HqFg6vGv9U8CJefnB-1WBqUuEHFy55lxrXbPSKmhnNbeiOXeiCUhpo020bCwBOlF4RcgQARr6yz8n1fzY2Y6biy0iVkNyXgQs0Q',
    status: 'Pending',
  },
  {
    id: 'leave-3',
    name: 'Pedro Reyes',
    type: 'Emergency',
    district: 'East Zone',
    crew: 'General Services',
    reason: 'Family emergency requires immediate attention out of town.',
    startDate: 'Oct 10, 2023',
    endDate: 'Oct 11, 2023',
    duration: '2 Days',
    initials: 'PR',
    status: 'Pending',
  },
];

export const initialAlerts: AlertItem[] = [
  {
    id: 'alert-1',
    type: 'Geofence Breach',
    title: 'Agent Out of Bounds',
    description: 'Worker #4829 left assigned zone (East Side).',
    timeAgo: '10 mins ago',
    severity: 'critical',
    expected: 'Zone B (East Side)',
    current: 'Sector 4 Off-Limits',
    workerInfo: {
      name: 'Mark D.',
      id: 'EMP-4829',
      team: 'Field Patrol B',
    },
  },
  {
    id: 'alert-2',
    type: 'Attendance Alert',
    title: 'Unreported Absence',
    description: 'Sarah J. has not clocked in for the morning shift. No leave filed.',
    timeAgo: '45 mins ago',
    severity: 'warning',
    workerInfo: {
      name: 'Sarah Jenkins',
      id: 'EMP-8422',
      team: 'Team Alpha',
      photoUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBwLZZF3ncjWpdvooi_EgLT--vq-DtgqyZaTKJmhhvnTJ6Dw_oOAktOI3iGEyiCneAuFFDSWRmPbSHVm5GSwbMkEJ8RMYOmEuawnr3sT_WlX99CQL13XxuGncc0xoy9gTgzUlo1fAWZrikpCGU-DYX3quNYTUnMC8GZbFuTxUkwboSqqAcpkygaSWreNo0TSHItIgJy5Uij7erSEmk5nRjx4pEqnPXljw4Ohrp87fD6E23E8i4SVfLf_hV092zIMDo2hThTFgaosxAZ',
    },
  },
  {
    id: 'alert-3',
    type: 'Score Warning',
    title: 'Low Performance Credit',
    description: "Team Beta's overall accomplishment score dropped below the 70% threshold.",
    timeAgo: '2 hrs ago',
    severity: 'warning',
    score: 68,
  },
  {
    id: 'alert-4',
    type: 'Overtime Request',
    title: 'Overtime Request',
    description: '5 new requests from South Harbor Dock.',
    timeAgo: '1 hr ago',
    severity: 'info',
  },
];

export const initialRecentActivity: RecentActivityItem[] = [
  {
    id: 'act-1',
    text: 'checked in at North Park.',
    highlightText: 'Maria Santos',
    timeAgo: 'Just now',
  },
  {
    id: 'act-2',
    text: 'auto-generated.',
    highlightText: 'Weekly report W42',
    timeAgo: '2 hrs ago',
  },
  {
    id: 'act-3',
    text: 'updated geofence coords.',
    highlightText: 'Admin John',
    timeAgo: 'Yesterday',
  },
];

export const initialBroadcasts: BroadcastNotification[] = [
  {
    id: 'bc-1',
    recipients: 'All Employees',
    subject: 'Server Maintenance Notice',
    body: 'Please be advised that the main portal will undergo scheduled maintenance this Sunday from 2:00 AM to 4:00 AM.',
    timestamp: '10:30 AM',
    deliveredCount: 142,
    confidential: false,
  },
  {
    id: 'bc-2',
    recipients: 'Supervisors Only',
    subject: 'Q3 Performance Review Guidelines',
    body: 'Attached are the updated rubrics for next week evaluation cycles. Ensure all team check-ins are logged.',
    timestamp: 'Yesterday',
    deliveredCount: 18,
    confidential: true,
  },
];
