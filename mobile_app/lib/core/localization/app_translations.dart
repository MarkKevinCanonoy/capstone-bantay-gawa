enum AppLanguage { filipino, english }

class AppTranslations {
  AppTranslations._();

  static const Map<String, Map<AppLanguage, String>> _values = {
    // Navigation & App Bar
    'app_title': {
      AppLanguage.filipino: 'BantayGawa',
      AppLanguage.english: 'BantayGawa',
    },
    'nav_home': {
      AppLanguage.filipino: 'Tahanan',
      AppLanguage.english: 'Home',
    },
    'nav_attendance': {
      AppLanguage.filipino: 'Attendance',
      AppLanguage.english: 'Attendance',
    },
    'nav_map': {
      AppLanguage.filipino: 'Mapa',
      AppLanguage.english: 'Map',
    },
    'nav_reports': {
      AppLanguage.filipino: 'Mga Ulat',
      AppLanguage.english: 'Reports',
    },
    'nav_profile': {
      AppLanguage.filipino: 'Profile',
      AppLanguage.english: 'Profile',
    },

    // Dashboard
    'greeting': {
      AppLanguage.filipino: 'Kamusta',
      AppLanguage.english: 'Hello',
    },
    'field_worker_badge': {
      AppLanguage.filipino: 'MANGGAGAWA SA KANAYON (FIELD WORKER)',
      AppLanguage.english: 'FIELD WORKER',
    },
    'current_status': {
      AppLanguage.filipino: 'KASALUKUYANG ESTADO',
      AppLanguage.english: 'CURRENT STATUS',
    },
    'in_zone': {
      AppLanguage.filipino: 'Nasa Sona (Authorized)',
      AppLanguage.english: 'Inside Zone (Authorized)',
    },
    'outside_zone': {
      AppLanguage.filipino: 'Nasa Labas ng Sona',
      AppLanguage.english: 'Outside Assigned Zone',
    },
    'morning_shift': {
      AppLanguage.filipino: 'Iskedyul: 06:00 AM - 02:00 PM (8 oras)',
      AppLanguage.english: 'Shift: 06:00 AM - 02:00 PM (8 hrs)',
    },
    'main_actions': {
      AppLanguage.filipino: 'MGA PANGUNAHING AKSYON',
      AppLanguage.english: 'MAIN ACTIONS',
    },
    'log_attendance': {
      AppLanguage.filipino: 'MAG-LOG NG ATTENDANCE',
      AppLanguage.english: 'LOG ATTENDANCE',
    },
    'log_attendance_sub': {
      AppLanguage.filipino: 'Time-in, Break-in, Break-out, o Time-out',
      AppLanguage.english: 'Time-in, Break-in, Break-out, or Time-out',
    },
    'upload_report': {
      AppLanguage.filipino: 'MAG-UPLOAD NG ULAT',
      AppLanguage.english: 'UPLOAD TASK REPORT',
    },
    'upload_report_sub': {
      AppLanguage.filipino: 'Magsumite ng patunay ng natapos na trabaho',
      AppLanguage.english: 'Submit proof of completed field task',
    },
    'request_leave': {
      AppLanguage.filipino: 'HUMILING NG LEAVE',
      AppLanguage.english: 'REQUEST LEAVE',
    },
    'request_leave_sub': {
      AppLanguage.filipino: 'Mag-apply ng Sick o Vacation Leave',
      AppLanguage.english: 'Apply for Sick or Vacation Leave',
    },
    'announcements': {
      AppLanguage.filipino: 'MGA ANUNSYO NG ENRO',
      AppLanguage.english: 'ENRO ANNOUNCEMENTS',
    },
    'announcements_sub': {
      AppLanguage.filipino: 'Mga abiso at babala mula sa Ormoc City Hall',
      AppLanguage.english: 'Official notices and alerts from Ormoc City Hall',
    },

    // Attendance
    'biometric_title': {
      AppLanguage.filipino: 'Pagpapatunay ng Mukha at GPS',
      AppLanguage.english: 'Face Biometrics & GPS Verification',
    },
    'position_face': {
      AppLanguage.filipino: 'Itapat ang mukha sa bilog',
      AppLanguage.english: 'Position face in frame',
    },
    'outside_geofence_warning': {
      AppLanguage.filipino: 'BABALA: Ikaw ay nasa labas ng itinalagang sona! Hindi maaaring mag-log ng attendance.',
      AppLanguage.english: 'WARNING: You are outside the assigned zone boundary! Attendance logging is locked.',
    },
    'time_in': {
      AppLanguage.filipino: 'ORAS NG PAGPASOK (TIME-IN)',
      AppLanguage.english: 'RECORD TIME-IN',
    },
    'break_in': {
      AppLanguage.filipino: 'SIMULA NG BREAK (BREAK-IN)',
      AppLanguage.english: 'RECORD BREAK-IN',
    },
    'break_out': {
      AppLanguage.filipino: 'TAPOS NG BREAK (BREAK-OUT)',
      AppLanguage.english: 'RECORD BREAK-OUT',
    },
    'time_out': {
      AppLanguage.filipino: 'ORAS NG LABAS (TIME-OUT)',
      AppLanguage.english: 'RECORD TIME-OUT',
    },

    // Reports / Accomplishments
    'task_title': {
      AppLanguage.filipino: 'Pangalan ng Gawain',
      AppLanguage.english: 'Task Title',
    },
    'task_photo_required': {
      AppLanguage.filipino: 'Patunay na Litrato (Naka-stamp ang GPS at Oras)',
      AppLanguage.english: 'Photo Proof (Watermarked with Time & GPS)',
    },
    'tap_to_capture': {
      AppLanguage.filipino: 'Pindutin upang kumuha ng litrato',
      AppLanguage.english: 'Tap to Capture Field Photo',
    },
    'task_details': {
      AppLanguage.filipino: 'Mga Detalye ng Natapos na Trabaho',
      AppLanguage.english: 'Accomplishment Details',
    },

    // Performance Credit Score
    'credit_score_title': {
      AppLanguage.filipino: 'Kredito sa Pagganap (Performance Score)',
      AppLanguage.english: 'Performance Credit Score',
    },
    'good_standing': {
      AppLanguage.filipino: 'Mabuting Kalagayan (Good Standing)',
      AppLanguage.english: 'Good Standing (80 - 100)',
    },
    'needs_improvement': {
      AppLanguage.filipino: 'Kailangang Pagbutihin (Babala)',
      AppLanguage.english: 'Needs Improvement (Warning)',
    },
    'critical_risk': {
      AppLanguage.filipino: 'Nasa Panganib (Kritikal)',
      AppLanguage.english: 'Critical Risk (Administrative Action)',
    },

    // Settings & Sync
    'language_setting': {
      AppLanguage.filipino: 'Wika / Language',
      AppLanguage.english: 'Language / Wika',
    },
    'tutorial_button': {
      AppLanguage.filipino: 'Tingnan ang Gabay sa Paggamit (Tutorial)',
      AppLanguage.english: 'View App Tutorial Walkthrough',
    },
    'sync_manager': {
      AppLanguage.filipino: 'Tagapamahala ng Offline Sync',
      AppLanguage.english: 'Offline Sync Manager',
    },
    'sync_now': {
      AppLanguage.filipino: 'I-sync Ngayon',
      AppLanguage.english: 'Sync Now',
    },
    'logout': {
      AppLanguage.filipino: 'Mag-sign Out sa Device',
      AppLanguage.english: 'Log Out of Device',
    },
  };

  static String get(String key, AppLanguage lang) {
    return _values[key]?[lang] ?? _values[key]?[AppLanguage.filipino] ?? key;
  }
}
