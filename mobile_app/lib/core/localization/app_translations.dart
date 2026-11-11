enum AppLanguage { cebuano, english }

class AppTranslations {
  AppTranslations._();

  static const Map<String, Map<AppLanguage, String>> _values = {
    // Navigation & App Bar
    'app_title': {
      AppLanguage.cebuano: 'BantayGawa',
      AppLanguage.english: 'BantayGawa',
    },
    'nav_home': {
      AppLanguage.cebuano: 'Home',
      AppLanguage.english: 'Home',
    },
    'nav_attendance': {
      AppLanguage.cebuano: 'Attendance',
      AppLanguage.english: 'Attendance',
    },
    'nav_map': {
      AppLanguage.cebuano: 'Mapa',
      AppLanguage.english: 'Map',
    },
    'nav_reports': {
      AppLanguage.cebuano: 'Mga Report',
      AppLanguage.english: 'Reports',
    },
    'nav_profile': {
      AppLanguage.cebuano: 'Profile',
      AppLanguage.english: 'Profile',
    },

    // Dashboard
    'greeting': {
      AppLanguage.cebuano: 'Maayong adlaw',
      AppLanguage.english: 'Hello',
    },
    'field_worker_badge': {
      AppLanguage.cebuano: 'TRABAHADOR SA FIELD',
      AppLanguage.english: 'FIELD WORKER',
    },
    'current_status': {
      AppLanguage.cebuano: 'KASAMTANGANG KAHIMTANG',
      AppLanguage.english: 'CURRENT STATUS',
    },
    'in_zone': {
      AppLanguage.cebuano: 'Sulod sa Area (Awtorisado)',
      AppLanguage.english: 'Inside Zone (Authorized)',
    },
    'outside_zone': {
      AppLanguage.cebuano: 'Gawas sa Assigned Area',
      AppLanguage.english: 'Outside Assigned Zone',
    },
    'morning_shift': {
      AppLanguage.cebuano: 'Iskedyul: 06:00 AM - 02:00 PM (8 ka oras)',
      AppLanguage.english: 'Shift: 06:00 AM - 02:00 PM (8 hrs)',
    },
    'schedule_prefix': {
      AppLanguage.cebuano: 'Iskedyul',
      AppLanguage.english: 'Schedule',
    },
    'unassigned_schedule': {
      AppLanguage.cebuano: 'Walay Na-assign nga Eskedyul',
      AppLanguage.english: 'Schedule Unassigned',
    },
    'unassigned_area': {
      AppLanguage.cebuano: 'Walay Na-assign nga Lugar',
      AppLanguage.english: 'No Assigned Area',
    },
    'main_actions': {
      AppLanguage.cebuano: 'PANGUNANG MGA BUHAT',
      AppLanguage.english: 'MAIN ACTIONS',
    },
    'log_attendance': {
      AppLanguage.cebuano: 'REKORD SA ATTENDANCE',
      AppLanguage.english: 'LOG ATTENDANCE',
    },
    'log_attendance_sub': {
      AppLanguage.cebuano: 'Time-in, Pahuway, o Time-out',
      AppLanguage.english: 'Time-in, Break-in, Break-out, or Time-out',
    },
    'upload_report': {
      AppLanguage.cebuano: 'PASA OG PROOF SA BUHAT',
      AppLanguage.english: 'UPLOAD TASK REPORT',
    },
    'upload_report_sub': {
      AppLanguage.cebuano: 'I-sumiter ang hulagway sa nahumang trabaho',
      AppLanguage.english: 'Submit proof of completed field task',
    },
    'request_leave': {
      AppLanguage.cebuano: 'PANGAYO OG LEAVE',
      AppLanguage.english: 'REQUEST LEAVE',
    },
    'request_leave_sub': {
      AppLanguage.cebuano: 'Mag-apply og Sick o Vacation Leave',
      AppLanguage.english: 'Apply for Sick or Vacation Leave',
    },
    'announcements': {
      AppLanguage.cebuano: 'MGA PAHIBALO SA ENRO',
      AppLanguage.english: 'ENRO ANNOUNCEMENTS',
    },
    'announcements_sub': {
      AppLanguage.cebuano: 'Opisyal nga pahibalo gikan sa Ormoc City Hall',
      AppLanguage.english: 'Official notices and alerts from Ormoc City Hall',
    },

    // Attendance
    'biometric_title': {
      AppLanguage.cebuano: 'Pag-ila sa Nawong ug GPS',
      AppLanguage.english: 'Face Biometrics & GPS Verification',
    },
    'position_face': {
      AppLanguage.cebuano: 'Ibutang ang nawong sulod sa lingin',
      AppLanguage.english: 'Position face in frame',
    },
    'outside_geofence_warning': {
      AppLanguage.cebuano: 'PAHIBALO: Anaa ka sa gawas sa imong area! Naka-lock ang attendance logging hangtod makabalik ka.',
      AppLanguage.english: 'WARNING: You are outside the assigned zone boundary! Attendance logging is locked.',
    },
    'time_in': {
      AppLanguage.cebuano: 'Pagsulod (Time In)',
      AppLanguage.english: 'Time In',
    },
    'break_in': {
      AppLanguage.cebuano: 'Pahuway (Break)',
      AppLanguage.english: 'Break',
    },
    'break_out': {
      AppLanguage.cebuano: 'Balik Trabaho (Resume)',
      AppLanguage.english: 'Resume',
    },
    'time_out': {
      AppLanguage.cebuano: 'Paggawas (Time Out)',
      AppLanguage.english: 'Time Out',
    },
    'status_not_started': {
      AppLanguage.cebuano: 'Wala Pa Nagsugod',
      AppLanguage.english: 'Not Started',
    },
    'status_on_duty': {
      AppLanguage.cebuano: 'Nakatrabaho',
      AppLanguage.english: 'On Duty',
    },
    'status_on_break': {
      AppLanguage.cebuano: 'Naka-Break',
      AppLanguage.english: 'On Break',
    },
    'status_shift_complete': {
      AppLanguage.cebuano: 'Nahuman ang Iskedyul',
      AppLanguage.english: 'Shift Ended',
    },
    'worked_hours': {
      AppLanguage.cebuano: 'Oras sa Trabaho',
      AppLanguage.english: 'Hours Worked',
    },
    'breaks_taken': {
      AppLanguage.cebuano: 'Mga Pahuway',
      AppLanguage.english: 'Breaks Taken',
    },
    'recent_attendance': {
      AppLanguage.cebuano: 'MGA NA-REKORD NGA ATTENDANCE',
      AppLanguage.english: 'RECENT ATTENDANCE LOGS',
    },
    'no_attendance_today': {
      AppLanguage.cebuano: 'Wala pay attendance record karong adlawa.',
      AppLanguage.english: 'No attendance records logged today.',
    },
    'all_actions_complete': {
      AppLanguage.cebuano: 'Nahuman na ang attendance karong adlawa (Naka Time-Out na).',
      AppLanguage.english: 'Shift completed for today (Timed out).',
    },
    'geofence_warning_title': {
      AppLanguage.cebuano: 'BABALA: NA-A SA GAWAS SA AREA',
      AppLanguage.english: 'WARNING: OUTSIDE GEOFENCE',
    },

    // Face Login & Biometrics
    'scan_face_login': {
      AppLanguage.cebuano: 'I-scan ang Nawong',
      AppLanguage.english: 'Scan Face',
    },
    'verifying_biometrics': {
      AppLanguage.cebuano: 'Gisusi...',
      AppLanguage.english: 'Verifying...',
    },
    'biometric_login_title': {
      AppLanguage.cebuano: 'Face Login',
      AppLanguage.english: 'Face Login',
    },
    'biometric_login_desc': {
      AppLanguage.cebuano: 'I-posisyon ang nawong sa lingin',
      AppLanguage.english: 'Position face inside the circle',
    },
    'liveness_check': {
      AppLanguage.cebuano: 'Liveness',
      AppLanguage.english: 'Liveness',
    },

    // Reports / Accomplishments
    'task_title': {
      AppLanguage.cebuano: 'Ngalan sa Buluhaton',
      AppLanguage.english: 'Task Title',
    },
    'task_photo_required': {
      AppLanguage.cebuano: 'Hulagway nga Patunay (May GPS ug Oras)',
      AppLanguage.english: 'Photo Proof (Watermarked with Time & GPS)',
    },
    'tap_to_capture': {
      AppLanguage.cebuano: 'Pindota aron mokuha og litrato',
      AppLanguage.english: 'Tap to Capture Field Photo',
    },
    'task_details': {
      AppLanguage.cebuano: 'Mga Detalye sa Nahumang Trabaho',
      AppLanguage.english: 'Accomplishment Details',
    },

    // Performance Credit Score
    'credit_score_title': {
      AppLanguage.cebuano: 'Puntos sa Trabaho (Performance Score)',
      AppLanguage.english: 'Performance Credit Score',
    },
    'good_standing': {
      AppLanguage.cebuano: 'Maayong Kahimtang (Good Standing)',
      AppLanguage.english: 'Good Standing (80 - 100)',
    },
    'needs_improvement': {
      AppLanguage.cebuano: 'Kinahanglan og Pagtagad (Pahimangno)',
      AppLanguage.english: 'Needs Improvement (Warning)',
    },
    'critical_risk': {
      AppLanguage.cebuano: 'Kritikal nga Kahimtang (Aksyon Gikinahanglan)',
      AppLanguage.english: 'Critical Risk (Administrative Action)',
    },

    // Settings & Sync
    'language_setting': {
      AppLanguage.cebuano: 'Pinulongan / Language',
      AppLanguage.english: 'Language / Pinulongan',
    },
    'tutorial_button': {
      AppLanguage.cebuano: 'Tan-awa ang Gabay sa Paggamit (Tutorial)',
      AppLanguage.english: 'View App Tutorial Walkthrough',
    },
    'sync_manager': {
      AppLanguage.cebuano: 'Tigdumala sa Offline Sync',
      AppLanguage.english: 'Offline Sync Manager',
    },
    'sync_now': {
      AppLanguage.cebuano: 'I-sync Karon',
      AppLanguage.english: 'Sync Now',
    },
    'logout': {
      AppLanguage.cebuano: 'Mobiya sa Device (Log Out)',
      AppLanguage.english: 'Log Out of Device',
    },

    // New Modules & Actions
    'report_worker': {
      AppLanguage.cebuano: 'I-report ang Trabahante',
      AppLanguage.english: 'Report Worker Issue',
    },
    'notifications_title': {
      AppLanguage.cebuano: 'Mga Pahibalo ug Alerto',
      AppLanguage.english: 'Notifications & Alerts',
    },
    'notifications_empty': {
      AppLanguage.cebuano: 'Walay bag-ong pahibalo.',
      AppLanguage.english: 'No notifications found.',
    },
    'monthly_summary': {
      AppLanguage.cebuano: 'Buwanang Talaan sa Pagtambong',
      AppLanguage.english: 'Monthly Attendance Summary',
    },
    'days_present': {
      AppLanguage.cebuano: 'Mitambong',
      AppLanguage.english: 'Days Present',
    },
    'days_tardy': {
      AppLanguage.cebuano: 'Naulahi (Late)',
      AppLanguage.english: 'Late',
    },
    'days_absent': {
      AppLanguage.cebuano: 'Wala (Absent)',
      AppLanguage.english: 'Absent',
    },
    'resubmit_report': {
      AppLanguage.cebuano: 'I-sumiter Pag-usab ang Report',
      AppLanguage.english: 'Resubmit Revised Accomplishment',
    },
    'camera_flip': {
      AppLanguage.cebuano: 'Balit-ad sa Camera',
      AppLanguage.english: 'Flip Camera',
    },
    'today_reports': {
      AppLanguage.cebuano: 'Mga Report Karong Adlawa',
      AppLanguage.english: "Today's Reports",
    },
    'no_reports_today': {
      AppLanguage.cebuano: 'Wala pay accomplishment report karong adlawa.',
      AppLanguage.english: 'No accomplishment reports submitted today.',
    },
    'view_past_reports': {
      AppLanguage.cebuano: 'Tan-awa ang Miaging mga Report',
      AppLanguage.english: 'View Past Reports',
    },
    'hide_past_reports': {
      AppLanguage.cebuano: 'Itago ang Miaging mga Report',
      AppLanguage.english: 'Hide Past Reports',
    },
    'retake_proof_hint': {
      AppLanguage.cebuano: 'Palihog pagkuha og bag-ong litrato sa ibabaw ug i-sumiter.',
      AppLanguage.english: 'Please take a new photo proof above and submit.',
    },
    'report_outside_zone_alert': {
      AppLanguage.cebuano: 'Gawas sa Zone • I-flag kini aron susihon sa supervisor',
      AppLanguage.english: 'Outside Work Zone • This report will be flagged for review',
    },
    'outside_zone_badge': {
      AppLanguage.cebuano: 'GAWAS SA ZONE',
      AppLanguage.english: 'OUTSIDE ZONE',
    },
  };

  static String get(String key, AppLanguage lang) {
    return _values[key]?[lang] ?? _values[key]?[AppLanguage.cebuano] ?? key;
  }
}
