import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const navy = Color(0xFF08284B);
const navyLight = Color(0xFF183D64);
const green = Color(0xFF167346);
const paleGreen = Color(0xFFE8F5EE);
const pageBg = Color(0xFFF7F8FC);
const borderColor = Color(0xFFD7DCE5);
const muted = Color(0xFF6D7787);
const red = Color(0xFFA92025);
const orange = Color(0xFFE97800);

enum AttendanceActionType { timeIn, breakIn, breakOut, timeOut }

extension AttendanceLabel on AttendanceActionType {
  String get label {
    switch (this) {
      case AttendanceActionType.timeIn:
        return 'Time-in';
      case AttendanceActionType.breakIn:
        return 'Break-in';
      case AttendanceActionType.breakOut:
        return 'Break-out';
      case AttendanceActionType.timeOut:
        return 'Time-out';
    }
  }
}

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

class WorkerNotifier extends Notifier<WorkerData> {
  @override
  WorkerData build() => WorkerData(
    workerName: 'Juan Dela Cruz',
    assignedZone: 'Sector 4 - Downtown Zone',
    creditScore: 85,
    logs: [],
    reports: [],
    leaves: [],
  );

  AttendanceActionType? get nextAction {
    final today = DateTime.now();
    final todayLogs = state.logs.where(
      (log) =>
          log.timestamp.year == today.year &&
          log.timestamp.month == today.month &&
          log.timestamp.day == today.day,
    );
    final completed = todayLogs.map((e) => e.type).toSet();

    if (!completed.contains(AttendanceActionType.timeIn)) {
      return AttendanceActionType.timeIn;
    }
    if (!completed.contains(AttendanceActionType.breakIn)) {
      return AttendanceActionType.breakIn;
    }
    if (!completed.contains(AttendanceActionType.breakOut)) {
      return AttendanceActionType.breakOut;
    }
    if (!completed.contains(AttendanceActionType.timeOut)) {
      return AttendanceActionType.timeOut;
    }
    return null;
  }

  void recordAttendance(AttendanceActionType type) {
    final now = DateTime.now();
    final log = AttendanceLog(
      id: now.microsecondsSinceEpoch.toString(),
      type: type,
      timestamp: now,
      // Demo coordinates only. Replace with a real location service.
      lat: 11.005,
      lng: 124.607,
      isSynced: false,
    );
    state = state.copyWith(logs: [log, ...state.logs]);
  }

  void submitProof(String description) {
    final now = DateTime.now();
    final report = AccomplishmentReport(
      id: now.microsecondsSinceEpoch.toString(),
      areaName: state.assignedZone,
      description: description,
      capturedAt: now,
      lat: 11.005,
      lng: 124.607,
    );
    state = state.copyWith(reports: [report, ...state.reports]);
  }

  void submitLeave(String type, DateTime start, DateTime end, String reason) {
    final leave = LeaveRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      startDate: start,
      endDate: end,
      reason: reason,
    );
    state = state.copyWith(leaves: [leave, ...state.leaves]);
  }
}

final workerProvider = NotifierProvider<WorkerNotifier, WorkerData>(
  WorkerNotifier.new,
);

void main() {
  runApp(const ProviderScope(child: BantayGawaMobileApp()));
}

class BantayGawaMobileApp extends StatelessWidget {
  const BantayGawaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BantayGawa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          primary: navy,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F6F9),
          contentPadding: const EdgeInsets.all(13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderColor),
          ),
        ),
      ),
      home: const MainShellView(),
    );
  }
}

class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(workerProvider);
    final pages = [
      DashboardView(
        onNavigate: (index) {
          setState(() => selectedIndex = index);
        },
      ),
      const AttendanceView(),
      const MapView(),
      const ReportsView(),
      const ProfileView(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 54,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: navy,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'LGU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BantayGawa',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          const Icon(Icons.wifi, size: 18, color: muted),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFE0E6EF),
            child: Text(
              worker.workerName.isNotEmpty ? worker.workerName[0] : 'W',
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Login will be implemented after the SRS update.',
                ),
              ),
            ),
            icon: const Icon(Icons.logout, color: red, size: 19),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCE8F6),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fingerprint),
            selectedIcon: Icon(Icons.fingerprint),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Reports',
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

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PageTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: navy,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: .35,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0808284B),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const StatusPill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// HOME
class DashboardView extends ConsumerWidget {
  final ValueChanged<int> onNavigate;

  const DashboardView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);
    final next = ref.read(workerProvider.notifier).nextAction;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          'Kamusta, ${worker.workerName.split(' ').first}!',
          style: const TextStyle(
            color: navy,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'FIELD WORKER  •  ID: 2024-001',
          style: TextStyle(color: muted, fontSize: 10),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KASALUKUYANG ESTADO',
                style: TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: navy,
                    radius: 17,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      worker.assignedZone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const StatusPill('Nasa Zone', green),
                ],
              ),
              const Divider(height: 24),
              const Row(
                children: [
                  Icon(Icons.access_time, size: 15, color: navy),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Morning Shift: 06:00 AM - 02:00 PM',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'ISKEDYUL SA PAGTATRABAHO NGAYON',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AttendanceActionType.values.map((action) {
                  final done = worker.logs.any(
                    (l) =>
                        l.type == action &&
                        DateUtils.isSameDay(l.timestamp, DateTime.now()),
                  );
                  final active = next == action;
                  final color = action == AttendanceActionType.breakIn
                      ? orange
                      : action == AttendanceActionType.timeOut
                      ? red
                      : green;
                  return SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 58) / 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: done
                            ? paleGreen
                            : active
                            ? const Color(0xFFF0F5FC)
                            : const Color(0xFFF5F6F9),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: active ? color : borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            done ? Icons.check_circle : _actionIcon(action),
                            color: done
                                ? green
                                : active
                                ? color
                                : muted,
                            size: 22,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            action.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            done
                                ? DateFormat('hh:mm a').format(
                                    worker.logs
                                        .firstWhere((l) => l.type == action)
                                        .timestamp,
                                  )
                                : active
                                ? 'Ready'
                                : 'Not yet',
                            style: const TextStyle(color: muted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Mga pangunahing aksyon'),
        _ActionTile(
          icon: Icons.fingerprint,
          title: 'LOG ATTENDANCE',
          subtitle: 'Time-in, Break-in, Break-out, or Time-out',
          onTap: () => onNavigate(1),
        ),
        _ActionTile(
          icon: Icons.cloud_upload_outlined,
          title: 'UPLOAD REPORTS',
          subtitle: 'Magsumite ng accomplishment',
          onTap: () => onNavigate(3),
        ),
        _ActionTile(
          icon: Icons.event_note,
          title: 'REQUEST LEAVE',
          subtitle: 'Mag-apply ng Sick o Vacation Leave',
          onTap: () => showLeaveDialog(context, ref),
        ),
        _ActionTile(
          icon: Icons.campaign_outlined,
          title: 'MGA ANUNSYO',
          subtitle: 'Walang bagong anunsyo sa ngayon',
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Mga Anunsyo'),
              content: const Text('Wala pang anunsyo na naka-load.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle(
          'Attendance ngayong araw',
          trailing: 'LOCAL DEMO DATA',
        ),
        if (worker.logs.isEmpty)
          const Panel(
            child: Text(
              'Wala pang attendance record ngayong araw.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          )
        else
          ...worker.logs
              .take(4)
              .map(
                (log) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const CircleAvatar(
                    backgroundColor: paleGreen,
                    child: Icon(Icons.check, color: green),
                  ),
                  title: Text(
                    log.type.label,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM d • hh:mm a').format(log.timestamp),
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: const StatusPill('PENDING SYNC', orange),
                ),
              ),
      ],
    );
  }
}

IconData _actionIcon(AttendanceActionType action) {
  switch (action) {
    case AttendanceActionType.timeIn:
      return Icons.login;
    case AttendanceActionType.breakIn:
      return Icons.coffee;
    case AttendanceActionType.breakOut:
      return Icons.free_breakfast;
    case AttendanceActionType.timeOut:
      return Icons.logout;
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: navy,
                  radius: 19,
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ATTENDANCE
class AttendanceView extends ConsumerWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);
    final next = ref.read(workerProvider.notifier).nextAction;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle(
          'Mobile Attendance',
          subtitle: 'Record your work attendance',
        ),
        Panel(
          padding: const EdgeInsets.all(10),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: navy,
                child: Icon(Icons.location_on, color: Colors.white, size: 16),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sector 4 - Downtown Zone',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'GPS verification not connected',
                      style: TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
              StatusPill('DEMO MODE', orange),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 270,
          decoration: BoxDecoration(
            color: const Color(0xFF07101E),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: navy, width: 1.5),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 12,
                left: 12,
                child: StatusPill('CAMERA NOT CONNECTED', Colors.white),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.face_retouching_natural,
                      color: Color(0xFF6CC5FF),
                      size: 94,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Face verification preview',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Camera integration pending',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  worker.workerName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Panel(
          child: Row(
            children: [
              Icon(Icons.gps_fixed, color: navy, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS & Geofence Verification',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live coordinates and zone validation are not yet connected.',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              StatusPill('UNVERIFIED', orange),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Mga aksyon sa attendance'),
        if (next == null)
          const Panel(
            child: Text(
              'Kumpleto na ang apat na attendance action para sa araw na ito.',
              style: TextStyle(fontSize: 12),
            ),
          )
        else
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: AttendanceActionType.values.map((action) {
              final enabled = action == next;
              final color = action == AttendanceActionType.breakIn
                  ? orange
                  : action == AttendanceActionType.timeOut
                  ? red
                  : navy;
              return SizedBox(
                width: (MediaQuery.sizeOf(context).width - 41) / 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: enabled ? color : const Color(0xFFE8EBF0),
                    foregroundColor: enabled ? Colors.white : muted,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: enabled
                      ? () => _recordDemoAttendance(context, ref, action)
                      : null,
                  icon: Icon(_actionIcon(action), size: 17),
                  label: Text(
                    action.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fallback selfie requires camera integration.'),
            ),
          ),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Fallback selfie (not connected)'),
        ),
        const SectionTitle('Mga na-record na attendance'),
        if (worker.logs.isEmpty)
          const Panel(
            child: Text(
              'Wala pang records. Ang demo records ay lokal lamang.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          )
        else
          ...worker.logs.map(
            (log) => Panel(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: paleGreen,
                    child: Icon(Icons.login, color: green, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.type.label,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy • hh:mm a')
                              .format(log.timestamp),
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill('LOCAL', orange),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

void _recordDemoAttendance(
  BuildContext context,
  WidgetRef ref,
  AttendanceActionType action,
) {
  ref.read(workerProvider.notifier).recordAttendance(action);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${action.label} saved locally as demo data.')),
  );
}

// MAP
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle('Geofence Map', subtitle: 'Your assigned work area'),
        const Panel(
          child: Row(
            children: [
              Icon(Icons.info_outline, color: green),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Map preview only. Live GPS and authorized boundary data are not connected.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 390,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F7),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: GridPainter())),
              Positioned(
                top: 18,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on, color: navy, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'Sector 4 - Downtown Zone',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 220,
                    height: 225,
                    decoration: BoxDecoration(
                      color: navy.withValues(alpha: .06),
                      border: Border.all(
                        color: navy,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on, color: navy, size: 42),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 24,
                bottom: 32,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: green, size: 11),
                    SizedBox(width: 5),
                    Text(
                      'Assigned zone preview',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 12,
                top: 70,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.my_location, color: navy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Panel(
          child: Row(
            children: [
              Icon(Icons.location_city, color: navy),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sector 4 - Downtown Zone',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Ormoc City • Assigned work zone',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              StatusPill('PREVIEW', orange),
            ],
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD7DCE5)
      ..strokeWidth = 0.7;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// REPORTS
class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(workerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle(
          'Submit Accomplishment',
          subtitle: 'Document your completed field work',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Issue reporting will be connected in a later step.',
                ),
              ),
            ),
            icon: const Icon(
              Icons.report_problem_outlined,
              color: red,
              size: 17,
            ),
            label: const Text(
              'Report issue',
              style: TextStyle(color: red, fontSize: 11),
            ),
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Task Title',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Drainage Inspection, Road Clearing',
                  hintStyle: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Photo Proof (Required Field Capture)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(height: 7),
              InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camera capture is not connected yet.'),
                  ),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1F23),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 31,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to Capture Field Photo',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Camera integration pending',
                        style: TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Accomplishment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the specific tasks completed...',
                  hintStyle: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final details = detailsController.text.trim();
                    if (title.isEmpty || details.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a task title and details first.',
                          ),
                        ),
                      );
                      return;
                    }
                    ref
                        .read(workerProvider.notifier)
                        .submitProof('$title — $details');
                    titleController.clear();
                    detailsController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Saved locally as a demo report. No photo or server upload yet.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Save Accomplishment'),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Recent reports', trailing: 'LOCAL RECORDS'),
        if (worker.reports.isEmpty)
          const Panel(
            child: Text(
              'Wala pang accomplishment report.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          )
        else
          ...worker.reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Field accomplishment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusPill(report.status.toUpperCase(), orange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('MMM d, yyyy • hh:mm a').format(report.capturedAt)}  •  ${report.areaName}',
                      style: const TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// PROFILE
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = ref.watch(workerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle('Worker Profile'),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: Color(0xFFE8EAF0),
                child: Icon(Icons.person, size: 48, color: navy),
              ),
              const SizedBox(height: 10),
              Text(
                worker.workerName,
                style: const TextStyle(
                  fontSize: 17,
                  color: navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'ID: 2024-001',
                style: TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 12),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  StatusPill('Field Worker', navy),
                  StatusPill('Morning Shift', green),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                worker.assignedZone,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Performance Credit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ),
                  Text(
                    'Demo score',
                    style: TextStyle(color: muted, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${worker.creditScore}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: worker.creditScore / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EBF0),
                  color: orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${worker.reports.length} local reports • ${worker.logs.length} attendance records',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SectionTitle('Attendance logs'),
        if (worker.logs.isEmpty)
          const Panel(
            child: Text(
              'Wala pang attendance records.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          )
        else
          ...worker.logs.map(
            (log) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const CircleAvatar(
                backgroundColor: paleGreen,
                child: Icon(Icons.access_time, color: green),
              ),
              title: Text(
                '${log.type.label} • ${worker.assignedZone}',
                style: const TextStyle(fontSize: 11, color: navy),
              ),
              subtitle: Text(
                DateFormat('MMM d • hh:mm a').format(log.timestamp),
                style: const TextStyle(fontSize: 10),
              ),
              trailing: const StatusPill('LOCAL', orange),
            ),
          ),
        const SectionTitle('Settings'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language, color: navy),
                title: const Text(
                  'Wika / Language',
                  style: TextStyle(fontSize: 12),
                ),
                subtitle: const Text(
                  'Language setting placeholder',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
                trailing: const Text(
                  'English',
                  style: TextStyle(fontSize: 10, color: navy),
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.sync, color: navy),
                title: Text('Sync Data Queue', style: TextStyle(fontSize: 12)),
                subtitle: Text(
                  'Local demo only; no server connection',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
                trailing: StatusPill('NOT CONNECTED', orange),
              ),
              const Divider(height: 1),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.event_note, color: navy),
                  title: const Text(
                    'My Leave Requests',
                    style: TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    '${worker.leaves.length} local requests',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLeaveDialog(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// LEAVE REQUEST DIALOG
Future<void> showLeaveDialog(BuildContext context, WidgetRef ref) async {
  final reasonController = TextEditingController();
  String type = 'Sick Leave';
  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(days: 1));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text(
          'Request Leave',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: const [
                  DropdownMenuItem(
                    value: 'Sick Leave',
                    child: Text('Sick Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'Emergency Leave',
                    child: Text('Emergency Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'Vacation Leave',
                    child: Text('Vacation Leave'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => type = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: start,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      start = picked;
                      if (end.isBefore(start)) end = start;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Start: ${DateFormat('MMM d, yyyy').format(start)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: end.isBefore(start) ? start : end,
                    firstDate: start,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => end = picked);
                },
                icon: const Icon(Icons.event),
                label: Text('End: ${DateFormat('MMM d, yyyy').format(end)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Enter your reason for leave',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason.')),
                );
                return;
              }
              ref
                  .read(workerProvider.notifier)
                  .submitLeave(type, start, end, reason);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Leave request saved locally as demo data.'),
                ),
              );
            },
            child: const Text('Save request'),
          ),
        ],
      ),
    ),
  );
  reasonController.dispose();
}
