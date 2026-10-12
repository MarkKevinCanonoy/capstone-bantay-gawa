import 'package:flutter_test/flutter_test.dart';
import 'package:web_dashboard/data/models/user_model.dart';
import 'package:web_dashboard/data/models/work_area_model.dart';
import 'package:web_dashboard/data/repositories/mock_repository.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MockRepository Data & Role Tests', () {
    late MockRepository repository;

    setUp(() {
      repository = MockRepository();
    });

    test('Loads initial work areas successfully', () async {
      final areas = await repository.getWorkAreas();
      expect(areas.isNotEmpty, isTrue);
      expect(areas.any((a) => a.name.contains('City Hall')), isTrue);
    });

    test('Scopes work areas to specific supervisor', () async {
      final areas = await repository.getWorkAreas(supervisorId: 'user-sup-1');
      expect(areas.every((a) => a.supervisorId == 'user-sup-1'), isTrue);
    });

    test('Filters employees by assigned area and role', () async {
      final workers = await repository.getUsers(role: UserRole.worker);
      expect(workers.every((u) => u.role == UserRole.worker), isTrue);

      final hallWorkers = await repository.getUsers(areaId: 'area-1');
      expect(hallWorkers.every((u) => u.assignedAreaId == 'area-1'), isTrue);
    });

    test('Toggles attendance verification', () async {
      final logs = await repository.getAttendanceLogs();
      final target = logs.first;
      final initialVerified = target.isVerified;

      await repository.toggleAttendanceVerify(target.attendanceId);
      final updatedLogs = await repository.getAttendanceLogs();
      final updated = updatedLogs.firstWhere((l) => l.attendanceId == target.attendanceId);

      expect(updated.isVerified, !initialVerified);
    });

    test('Approves accomplishment report with reviewer name', () async {
      final proofs = await repository.getAccomplishments();
      final target = proofs.firstWhere((p) => p.status == 'pending');

      await repository.updateAccomplishmentStatus(
        target.accomplishmentId,
        'approved',
        approvedBy: 'user-admin-1',
        approvedByName: 'Roberto Del Rosario',
      );

      final updatedProofs = await repository.getAccomplishments();
      final updated = updatedProofs.firstWhere((p) => p.accomplishmentId == target.accomplishmentId);

      expect(updated.status, 'approved');
      expect(updated.approvedByName, 'Roberto Del Rosario');
    });

    test('Adds a new work area', () async {
      final newArea = WorkAreaModel(
        workareaId: 'area-new',
        name: 'Ormoc Port Zone',
        supervisorName: 'Juan Santos',
        polygon: const [
          LatLng(11.001, 124.601),
          LatLng(11.002, 124.602),
          LatLng(11.003, 124.603),
        ],
      );

      await repository.addWorkArea(newArea);
      final all = await repository.getWorkAreas();
      expect(all.any((a) => a.workareaId == 'area-new'), isTrue);
    });

    test('Updates an existing work area', () async {
      final areas = await repository.getWorkAreas();
      final target = areas.first;
      final updated = target.copyWith(name: 'Ormoc City Hall - Renamed');

      await repository.updateWorkArea(updated);
      final updatedAreas = await repository.getWorkAreas();
      final found = updatedAreas.firstWhere((a) => a.workareaId == target.workareaId);
      expect(found.name, 'Ormoc City Hall - Renamed');
    });

    test('Deletes a work area', () async {
      final areas = await repository.getWorkAreas();
      final target = areas.first;

      await repository.deleteWorkArea(target.workareaId);
      final remainingAreas = await repository.getWorkAreas();
      expect(remainingAreas.any((a) => a.workareaId == target.workareaId), isFalse);
    });

    test('Assigns unassigned worker to existing work area and updates assignedCount', () async {
      final workersBefore = await repository.getUsers(role: UserRole.worker);
      final unassigned = workersBefore.firstWhere((w) => w.assignedAreaId == null);

      await repository.assignWorkerToArea(
        workerId: unassigned.userId,
        areaId: 'area-1',
        areaName: 'Ormoc City Hall Zone',
      );

      final workersAfter = await repository.getUsers(role: UserRole.worker);
      final updatedWorker = workersAfter.firstWhere((w) => w.userId == unassigned.userId);
      expect(updatedWorker.assignedAreaId, 'area-1');
      expect(updatedWorker.assignedAreaName, 'Ormoc City Hall Zone');

      final areas = await repository.getWorkAreas();
      final area1 = areas.firstWhere((a) => a.workareaId == 'area-1');
      expect(area1.assignedCount > 0, isTrue);
    });

    test('Dynamically assigns workers to a newly created work area', () async {
      final newArea = WorkAreaModel(
        workareaId: 'area-custom-dynamic-1',
        name: 'Ormoc Port New Terminal',
        supervisorName: 'Juan Santos',
        polygon: const [
          LatLng(11.002, 124.602),
          LatLng(11.003, 124.603),
          LatLng(11.004, 124.604),
        ],
      );

      await repository.addWorkArea(newArea);
      var areas = await repository.getWorkAreas();
      var created = areas.firstWhere((a) => a.workareaId == 'area-custom-dynamic-1');
      expect(created.assignedCount, 0);

      // Assign worker to this brand new area
      final workers = await repository.getUsers(role: UserRole.worker);
      final targetWorker = workers.firstWhere((w) => w.assignedAreaId == null);

      await repository.assignWorkerToArea(
        workerId: targetWorker.userId,
        areaId: newArea.workareaId,
        areaName: newArea.name,
      );

      areas = await repository.getWorkAreas();
      created = areas.firstWhere((a) => a.workareaId == 'area-custom-dynamic-1');
      expect(created.assignedCount, 1);

      // Unassign worker
      await repository.assignWorkerToArea(
        workerId: targetWorker.userId,
        areaId: null,
        areaName: null,
      );

      areas = await repository.getWorkAreas();
      created = areas.firstWhere((a) => a.workareaId == 'area-custom-dynamic-1');
      expect(created.assignedCount, 0);

      final unassignedWorker = (await repository.getUsers(role: UserRole.worker))
          .firstWhere((w) => w.userId == targetWorker.userId);
      expect(unassignedWorker.assignedAreaId, isNull);
      expect(unassignedWorker.assignedAreaName, isNull);
    });
  });
}
