import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// --- DATA MODELS ---
enum AttendanceActionType { timeIn, breakIn, breakOut, timeOut }

class AttendanceLog {
  final String id;
  final AttendanceActionType type;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final bool isSynced;

  AttendanceLog({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.isSynced = false,
  });
}

class AccomplishmentReport {
  final String id;
  final String areaName;
  final String description;
  final DateTime capturedAt;
  final double lat;
  final double lng;
  final String status;
  final bool isSynced;

  AccomplishmentReport({
    required this.id,
    required this.areaName,
    required this.description,
    required this.capturedAt,
    required this.lat,
    required this.lng,
    this.status = 'Pending',
    this.isSynced = false,
  });
}

class LeaveRequest {
  final String id;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;

  LeaveRequest({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'Pending',
  });
}

class WorkerData {
  final String workerName;
  final String assignedZone;
  final int creditScore;
  final List<AttendanceLog> logs;
  final List<AccomplishmentReport> reports;
  final List<LeaveRequest> leaves;

  WorkerData({
    required this.workerName,
    required this.assignedZone,
    required this.creditScore,
    required this.logs,
    required this.reports,
    required this.leaves,
  });

  WorkerData copyWith({
    String? workerName,
    String? assignedZone,
    int? creditScore,
    List<AttendanceLog>? logs,
    List<AccomplishmentReport>? reports,
    List<LeaveRequest>? leaves,
  }) {
    return WorkerData(
      workerName: workerName ?? this.workerName,
      assignedZone: assignedZone ?? this.assignedZone,
      creditScore: creditScore ?? this.creditScore,
      logs: logs ?? this.logs,
      reports: reports ?? this.reports,
      leaves: leaves ?? this.leaves,
    );
  }
}

// --- RIVERPOD NOTIFIER ---
class WorkerNotifier extends Notifier<WorkerData> {
  @override
  WorkerData build() {
    return WorkerData(
      workerName: "Juan Dela Cruz",
      assignedZone: "Ormoc City Plaza Zone A",
      creditScore: 92,
      logs: [],
      reports: [],
      leaves: [],
    );
  }

  void recordAttendance(AttendanceActionType type) {
    final newLog = AttendanceLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: DateTime.now(),
      lat: 11.0064,
      lng: 124.6075,
      isSynced: false,
    );
    state = state.copyWith(logs: [newLog, ...state.logs]);
  }

  void submitProof(String description) {
    final newReport = AccomplishmentReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      areaName: state.assignedZone,
      description: description,
      capturedAt: DateTime.now(),
      lat: 11.0064,
      lng: 124.6075,
    );
    state = state.copyWith(reports: [newReport, ...state.reports]);
  }

  void submitLeave(String type, DateTime start, DateTime end, String reason) {
    final newLeave = LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      startDate: start,
      endDate: end,
      reason: reason,
    );
    state = state.copyWith(leaves: [newLeave, ...state.leaves]);
  }
}

final workerProvider = NotifierProvider<WorkerNotifier, WorkerData>(() {
  return WorkerNotifier();
});

// --- MAIN ENTRYPOINT ---
void main() {
  runApp(const ProviderScope(child: BantayGawaMobileApp()));
}

class BantayGawaMobileApp extends StatelessWidget {
  const BantayGawaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bantay Gawa Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF0288D1),
          surface: const Color(0xFFF8F9FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F3F5),
      ),
      home: const MainShellView(),
    );
  }
}

// --- MAIN SHELL ---
class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardView(),
    AttendanceView(),
    AccomplishmentView(),
    LeaveRequestView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(workerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bantay Gawa Field Worker',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Zone: ${worker.assignedZone}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${worker.creditScore} pts',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Proof',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Leave',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// 1. DASHBOARD VIEW
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          color: const Color(0xFFE8F5E9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1B5E20),
                  child: Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Assigned Geofence',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        worker.assignedZone,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Inside Work Boundary',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quick Attendance Actions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(workerProvider.notifier)
                      .recordAttendance(AttendanceActionType.timeIn);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Time-In Recorded Successfully!'),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('TIME IN'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(workerProvider.notifier)
                      .recordAttendance(AttendanceActionType.timeOut);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Time-Out Recorded Successfully!'),
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('TIME OUT'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Today\'s Activity History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        worker.logs.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No attendance logs for today.')),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: worker.logs.length,
                itemBuilder: (context, i) {
                  final log = worker.logs[i];
                  final timeStr = DateFormat('hh:mm a').format(log.timestamp);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        log.type == AttendanceActionType.timeIn
                            ? Icons.login
                            : Icons.logout,
                        color: log.type == AttendanceActionType.timeIn
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(
                        log.type.name.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '$timeStr • Lat: ${log.lat}, Lng: ${log.lng}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: log.isSynced
                              ? Colors.blue.shade50
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.isSynced ? 'Synced' : 'Offline Cache',
                          style: TextStyle(
                            fontSize: 10,
                            color: log.isSynced
                                ? Colors.blue.shade800
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

// 2. ATTENDANCE & FACIAL RECOGNITION VIEW
class AttendanceView extends ConsumerWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1B5E20), width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.person, size: 100, color: Colors.white30),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Face Biometrics Ready',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.gps_fixed, color: Color(0xFF1B5E20)),
              title: Text('GPS & Geofence Verification'),
              subtitle: Text(
                'Lat: 11.0064, Lng: 124.6075\nStatus: Verified Inside Zone',
              ),
              isThreeLine: true,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              ref
                  .read(workerProvider.notifier)
                  .recordAttendance(AttendanceActionType.timeIn);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Facial Recognition Passed & Attendance Logged!',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.camera),
            label: const Text('SCAN FACE & LOG ATTENDANCE'),
          ),
        ],
      ),
    );
  }
}

// 3. ACCOMPLISHMENT REPORT VIEW
class AccomplishmentView extends ConsumerWidget {
  const AccomplishmentView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);
    final textController = TextEditingController();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Task Accomplishment Proof',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.black54),
                      SizedBox(height: 8),
                      Text('Tap to Capture Geotagged Photo'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Task Accomplishment Description',
                    hintText: 'e.g. Completed street sweeping along Ormoc Plaza Sector 2.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: () {
                    if (textController.text.isNotEmpty) {
                      ref
                          .read(workerProvider.notifier)
                          .submitProof(textController.text);
                      textController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Accomplishment Proof Submitted!'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('SUBMIT PROOF'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Submitted Reports',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        worker.reports.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No submitted reports yet.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: worker.reports.length,
                itemBuilder: (context, i) {
                  final r = worker.reports[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      title: Text(
                        r.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('MMM dd, hh:mm a').format(r.capturedAt)} • ${r.areaName}',
                      ),
                      trailing: Chip(
                        label: Text(
                          r.status,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.amber.shade100,
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

// 4. LEAVE REQUEST VIEW
class LeaveRequestView extends ConsumerWidget {
  const LeaveRequestView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);
    final reasonController = TextEditingController();
    String selectedType = 'Sick Leave';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File a Leave Request',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Sick Leave',
                            'Emergency Leave',
                            'Vacation Leave',
                            'Other',
                          ]
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                  onChanged: (v) => selectedType = v!,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Leave',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: () {
                    if (reasonController.text.isNotEmpty) {
                      ref
                          .read(workerProvider.notifier)
                          .submitLeave(
                            selectedType,
                            DateTime.now(),
                            DateTime.now().add(const Duration(days: 1)),
                            reasonController.text,
                          );
                      reasonController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Leave Request Filed Successfully!'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('SUBMIT LEAVE REQUEST'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'My Leave History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        worker.leaves.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No leave requests filed.'),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: worker.leaves.length,
                itemBuilder: (context, i) {
                  final l = worker.leaves[i];
                  return Card(
                    child: ListTile(
                      title: Text('${l.type} (${l.status})'),
                      subtitle: Text('Reason: ${l.reason}'),
                      trailing: Text(DateFormat('MMM dd').format(l.startDate)),
                    ),
                  );
                },
              ),
      ],
    );
  }
}

// 5. PROFILE & CREDITS VIEW
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF1B5E20),
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  worker.workerName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Text('Field Worker • ENRO Ormoc'),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${worker.creditScore}',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Credit Score',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${worker.logs.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'Total Logs',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
