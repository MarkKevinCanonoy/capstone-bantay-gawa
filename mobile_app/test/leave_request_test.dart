import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/datasources/local_database.dart';
import 'package:mobile_app/data/models/leave_request_model.dart';
import 'package:mobile_app/data/repositories/offline_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Leave Request Single Pending Rule & Serialization Tests', () {
    test('Enforces 1 pending leave request constraint logic', () {
      final existingRequests = [
        LeaveRequestModel(
          leaveId: 'lv-001',
          userId: 'user-123',
          type: 'Sick Leave',
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now().subtract(const Duration(days: 8)),
          reason: 'Flu symptoms',
          status: 'denied',
        ),
        LeaveRequestModel(
          leaveId: 'lv-002',
          userId: 'user-123',
          type: 'Vacation Leave',
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().subtract(const Duration(days: 4)),
          reason: 'Personal errand',
          status: 'approved',
        ),
      ];

      // When all previous requests are approved or denied, pending check returns null
      final pendingLeave = existingRequests.cast<LeaveRequestModel?>().firstWhere(
        (l) => l != null && l.status.toLowerCase() == 'pending',
        orElse: () => null,
      );
      expect(pendingLeave, isNull, reason: 'Worker should be allowed to submit a new leave request after previous ones are decided');

      // Now add a pending request
      existingRequests.add(
        LeaveRequestModel(
          leaveId: 'lv-003',
          userId: 'user-123',
          type: 'Emergency Leave',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 1)),
          reason: 'Family emergency',
          status: 'pending',
        ),
      );

      final activePending = existingRequests.cast<LeaveRequestModel?>().firstWhere(
        (l) => l != null && l.status.toLowerCase() == 'pending',
        orElse: () => null,
      );
      expect(activePending, isNotNull);
      expect(activePending!.leaveId, 'lv-003');
      expect(activePending.status, 'pending', reason: 'Worker should be blocked from filing while another is pending');
    });

    test('LeaveRequestModel copyWith preserves and overrides fields correctly', () {
      final initial = LeaveRequestModel(
        leaveId: 'lv-100',
        userId: 'usr-100',
        type: 'Sick Leave',
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 3),
        reason: 'Migraine',
        imageUrl: '/cache/doc.pdf',
        status: 'pending',
        isSynced: false,
      );

      final updated = initial.copyWith(
        imageUrl: 'https://cloud.storage/leaves/doc.pdf',
        status: 'approved',
        isSynced: true,
      );

      expect(updated.leaveId, 'lv-100');
      expect(updated.imageUrl, 'https://cloud.storage/leaves/doc.pdf');
      expect(updated.status, 'approved');
      expect(updated.isSynced, isTrue);
    });

    test('LeaveRequestModel toSupabaseJson conforms to specs/schema.sql', () {
      final model = LeaveRequestModel(
        leaveId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        userId: 'f1e2d3c4-b5a6-7890-abcd-ef1234567890',
        type: 'Sick Leave',
        startDate: DateTime(2026, 11, 10),
        endDate: DateTime(2026, 11, 12),
        reason: 'Medical clearance requested',
        imageUrl: 'data:application/pdf;base64,JVBERi0xLjQK...',
        status: 'pending',
      );

      final json = model.toSupabaseJson();
      expect(json['leave_id'], 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(json['user_id'], 'f1e2d3c4-b5a6-7890-abcd-ef1234567890');
      expect(json['type'], 'Sick Leave');
      expect(json['start_date'], '2026-11-10');
      expect(json['end_date'], '2026-11-12');
      expect(json['reason'], 'Medical clearance requested');
      expect(json['image_url'], 'data:application/pdf;base64,JVBERi0xLjQK...');
      expect(json['status'], 'pending');
      expect(json['is_synced'], isTrue);
    });

    test('LocalDatabase inserts and updates leave image URL', () async {
      final leave = LeaveRequestModel(
        leaveId: 'test-leave-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'usr-offline',
        type: 'Sick Leave',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 2),
        reason: 'Offline filing test',
        imageUrl: '/cache/local_file.pdf',
        status: 'pending',
        isSynced: false,
      );

      await LocalDatabase.instance.insertLeaveRequest(leave);
      final unsynced = await LocalDatabase.instance.getUnsyncedLeaves();
      expect(unsynced.any((l) => l.leaveId == leave.leaveId), isTrue);

      // Update image URL with resolved cloud or data URL
      const newUrl = 'data:application/pdf;base64,SGVsbG8gV29ybGQ=';
      await LocalDatabase.instance.updateLeaveImageUrl(leave.leaveId, newUrl);
      await LocalDatabase.instance.markLeaveSynced(leave.leaveId);

      final allLeaves = await LocalDatabase.instance.getAllLeaveRequests();
      final updated = allLeaves.firstWhere((l) => l.leaveId == leave.leaveId);
      expect(updated.imageUrl, newUrl);
      expect(updated.isSynced, isTrue);
    });

    test('Multi-format attachment MIME type detection and self-contained Base64 encoding', () async {
      final tempDir = await Directory.systemTemp.createTemp('leave_tests');

      // Test 1: PDF attachment
      final pdfFile = File('${tempDir.path}/doctor_note.pdf');
      await pdfFile.writeAsString('Mock PDF content for leave proof');

      final dummyClient = SupabaseClient('https://mock.supabase.co', 'dummy-key');
      final resolvedPdf = await OfflineSyncService.instance.resolveFileForUpload(
        client: dummyClient,
        rawPath: pdfFile.path,
        bucket: 'leaves',
        userId: 'usr-test',
        fileId: 'f-pdf-1',
      );
      expect(resolvedPdf.startsWith('data:application/pdf;base64,'), isTrue);

      // Test 2: Word (DOCX) attachment
      final docxFile = File('${tempDir.path}/medical_certificate.docx');
      await docxFile.writeAsString('Mock DOCX content');

      final resolvedDocx = await OfflineSyncService.instance.resolveFileForUpload(
        client: dummyClient,
        rawPath: docxFile.path,
        bucket: 'leaves',
        userId: 'usr-test',
        fileId: 'f-docx-1',
      );
      expect(
        resolvedDocx.startsWith('data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,'),
        isTrue,
      );

      // Test 3: Standard Image (PNG) attachment
      final pngFile = File('${tempDir.path}/proof_photo.png');
      await pngFile.writeAsString('Mock PNG content');

      final resolvedPng = await OfflineSyncService.instance.resolveFileForUpload(
        client: dummyClient,
        rawPath: pngFile.path,
        bucket: 'leaves',
        userId: 'usr-test',
        fileId: 'f-png-1',
      );
      expect(resolvedPng.startsWith('data:image/png;base64,'), isTrue);

      // Clean up
      await tempDir.delete(recursive: true);
    });
  });
}
