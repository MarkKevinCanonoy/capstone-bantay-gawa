import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/uuid_helper.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/datasources/local_database.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/mobile_repository_provider.dart';

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _getAttachmentDisplayName(String? url) {
  if (url == null || url.trim().isEmpty) return 'Document';
  final trimmed = url.trim();
  if (trimmed.startsWith('data:')) {
    final mime = trimmed.substring(5).split(';').first.toLowerCase();
    if (mime.contains('pdf')) return 'Medical_Certificate.pdf';
    if (mime.contains('word') || mime.contains('officedocument') || mime.contains('doc')) {
      return 'Supporting_Document.docx';
    }
    if (mime.contains('image')) return 'Proof_Photo.jpg';
    if (mime.contains('text')) return 'Document.txt';
    return 'Supporting_Document';
  }
  final clean = trimmed.split('?').first;
  final name = clean.split('/').last;
  if (name.length > 28) {
    final extIndex = name.lastIndexOf('.');
    if (extIndex != -1 && extIndex > name.length - 6) {
      final ext = name.substring(extIndex);
      return '${name.substring(0, 20)}...$ext';
    }
    return '${name.substring(0, 25)}...';
  }
  return name.isNotEmpty ? name : 'Document';
}

IconData _getFileIcon(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
  if (ext == 'docx' || ext == 'doc') return Icons.description_rounded;
  if (ext == 'txt') return Icons.article_rounded;
  return Icons.image_rounded;
}

Color _getFileColor(String path) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  if (ext == 'pdf') return Colors.red.shade700;
  if (ext == 'docx' || ext == 'doc') return Colors.blue.shade700;
  if (ext == 'txt') return Colors.teal.shade700;
  return AppColors.accentGreen;
}

Future<String> _compressAndSaveImage(String sourcePath) async {
  try {
    final file = File(sourcePath);
    if (!await file.exists()) return sourcePath;
    final bytes = await file.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return sourcePath;

    decoded = img.bakeOrientation(decoded);
    if (decoded.width > 1024 || decoded.height > 1024) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: 1024);
      } else {
        decoded = img.copyResize(decoded, height: 1024);
      }
    }
    final compressedBytes = img.encodeJpg(decoded, quality: 75);
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(compressedBytes);
    return outPath;
  } catch (e) {
    debugPrint('Image compression error: $e');
    return sourcePath;
  }
}

Future<void> showLeaveRequestDialog(BuildContext context, WidgetRef ref) async {
  // 1. Business Rule: Check if the worker already has an active pending leave request
  final existingLeaves = ref.read(leaveRequestListProvider).value ?? 
      await LocalDatabase.instance.getAllLeaveRequests();
  final activePending = existingLeaves.cast<LeaveRequestModel?>().firstWhere(
    (l) => l != null && l.status.toLowerCase() == 'pending',
    orElse: () => null,
  );

  if (activePending != null) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pending_actions_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Active Leave Pending',
                style: TextStyle(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You currently have a leave request awaiting supervisor review. ENRO guidelines permit one pending request at a time.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activePending.type,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Duration: ${DateFormat('MMM d, y').format(activePending.startDate)} - ${DateFormat('MMM d, y').format(activePending.endDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  if (activePending.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${activePending.reason}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once reviewed (approved or declined), you will be able to file another request if needed.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Understood',
            isFullWidth: true,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _LeaveRequestDialogWidget(parentContext: context),
  );
}

class _LeaveRequestDialogWidget extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  const _LeaveRequestDialogWidget({required this.parentContext});

  @override
  ConsumerState<_LeaveRequestDialogWidget> createState() => _LeaveRequestDialogWidgetState();
}

class _LeaveRequestDialogWidgetState extends ConsumerState<_LeaveRequestDialogWidget> {
  late final TextEditingController _reasonController;
  String _selectedType = 'Sick Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _attachedProofPath;
  String? _attachedFileName;
  int? _attachedFileSize;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(BuildContext sheetContext) async {
    final choice = await showModalBottomSheet<String>(
      context: sheetContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Attach Medical Proof or Document',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryNavy),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.accentBlue),
                ),
                title: const Text('Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('JPEG, PNG, WEBP medical certificates or receipts', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                onTap: () => Navigator.pop(bCtx, 'gallery'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.purple),
                ),
                title: const Text('Document / Files (PDF, Word, Text)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('PDF, DOCX, DOC, or TXT documents (up to 10 MB)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                onTap: () => Navigator.pop(bCtx, 'document'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.accentGreen),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Capture medical certificate or official memo directly', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                onTap: () => Navigator.pop(bCtx, 'camera'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'gallery') {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (files.isNotEmpty && mounted) {
          final file = files.first;
          final safeName = file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
          String filePath;
          if (file.path != null && await File(file.path!).exists()) {
            filePath = file.path!;
          } else {
            final bytes = await file.readAsBytes();
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName');
            await tempFile.writeAsBytes(bytes);
            filePath = tempFile.path;
          }
          final compressedPath = await _compressAndSaveImage(filePath);
          final len = await File(compressedPath).length();
          if (mounted) {
            setState(() {
              _attachedProofPath = compressedPath;
              _attachedFileName = file.name;
              _attachedFileSize = len;
            });
          }
        }
      } catch (e) {
        debugPrint('Gallery picker error: $e');
        if (mounted) {
          ToastNotification.showError(context, 'Could not read selected photo: $e');
        }
      }
    } else if (choice == 'document') {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
        );
        if (files.isNotEmpty && mounted) {
          final file = files.first;
          final reportedLen = file.lengthSync() ?? (await file.length()) ?? 0;
          if (reportedLen > 10 * 1024 * 1024) {
            if (mounted) {
              ToastNotification.showWarning(context, 'Document exceeds maximum size of 10 MB.');
            }
            return;
          }
          final safeName = file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
          String filePath;
          if (file.path != null && await File(file.path!).exists()) {
            filePath = file.path!;
          } else {
            final bytes = await file.readAsBytes();
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName');
            await tempFile.writeAsBytes(bytes);
            filePath = tempFile.path;
          }
          final finalLen = await File(filePath).length();
          if (finalLen > 10 * 1024 * 1024) {
            if (mounted) {
              ToastNotification.showWarning(context, 'Document exceeds maximum size of 10 MB.');
            }
            return;
          }
          if (mounted) {
            setState(() {
              _attachedProofPath = filePath;
              _attachedFileName = file.name;
              _attachedFileSize = finalLen;
            });
          }
        }
      } catch (e) {
        debugPrint('Document picker error: $e');
        if (mounted) {
          ToastNotification.showError(context, 'Could not read selected document: $e');
        }
      }
    } else if (choice == 'camera') {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
          await controller.initialize();
          final photo = await controller.takePicture();
          await controller.dispose();
          final compressedPath = await _compressAndSaveImage(photo.path);
          final len = await File(compressedPath).length();
          if (mounted) {
            setState(() {
              _attachedProofPath = compressedPath;
              _attachedFileName = 'cert_${DateTime.now().millisecondsSinceEpoch}.jpg';
              _attachedFileSize = len;
            });
          }
        } else {
          final dir = await getTemporaryDirectory();
          final sampleFile = File('${dir.path}/med_cert_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await sampleFile.writeAsBytes(List.filled(100, 0));
          if (mounted) {
            setState(() {
              _attachedProofPath = sampleFile.path;
              _attachedFileName = sampleFile.path.split('/').last;
              _attachedFileSize = 100;
            });
          }
        }
      } catch (e) {
        debugPrint('Camera capture error: $e');
        try {
          final dir = await getTemporaryDirectory();
          final sampleFile = File('${dir.path}/med_cert_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await sampleFile.writeAsBytes(List.filled(100, 0));
          if (mounted) {
            setState(() {
              _attachedProofPath = sampleFile.path;
              _attachedFileName = sampleFile.path.split('/').last;
              _attachedFileSize = 100;
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ToastNotification.showWarning(context, 'Please enter a reason for your leave.');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ToastNotification.showWarning(context, 'End date cannot be earlier than start date.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider).value;
      final area = ref.read(assignedWorkAreaProvider).value;

      final leave = LeaveRequestModel(
        leaveId: UuidHelper.generate(),
        userId: user?.userId ?? '',
        workerName: user?.fullName ?? '',
        workareaId: area?.workareaId,
        areaName: area?.name.isNotEmpty == true ? area!.name : 'Unassigned Area',
        type: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
        reason: reason,
        imageUrl: _attachedProofPath,
        status: 'pending',
        isSynced: false,
      );

      await ref.read(leaveRequestListProvider.notifier).submit(leave);

      if (mounted) {
        Navigator.pop(context);
      }
      if (widget.parentContext.mounted) {
        ToastNotification.showSuccess(widget.parentContext, 'Leave request submitted (Pending Supervisor review).');
      }
    } catch (e) {
      debugPrint('Error submitting leave request: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastNotification.showError(context, 'Could not submit leave request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Request Leave',
        style: TextStyle(
          color: AppColors.primaryNavy,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                DropdownMenuItem(value: 'Emergency Leave', child: Text('Emergency Leave')),
                DropdownMenuItem(value: 'Vacation Leave', child: Text('Vacation Leave')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 12),

            // Inclusive Dates
            const Text('Inclusive Dates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      DateFormat('MMM d').format(_startDate),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('to', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event, size: 14),
                    label: Text(
                      DateFormat('MMM d').format(_endDate),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Reason (Required)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Enter reason for leave request...',
                hintStyle: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),

            // Supporting Document Attachment (Multi-format)
            const Text('Supporting Proof / Document (Optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (_attachedProofPath != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getFileColor(_attachedProofPath!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(_getFileIcon(_attachedProofPath!), size: 20, color: _getFileColor(_attachedProofPath!)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedFileName ?? _getAttachmentDisplayName(_attachedProofPath),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_attachedFileSize != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(_attachedFileSize!),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      tooltip: 'Remove Attachment',
                      onPressed: () {
                        setState(() {
                          _attachedProofPath = null;
                          _attachedFileName = null;
                          _attachedFileSize = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _pickAttachment(context),
                icon: const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primaryNavy),
                label: const Text(
                  'Attach Proof (Gallery, PDF, Document, Camera)',
                  style: TextStyle(fontSize: 11, color: AppColors.primaryNavy),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        AppButton(
          label: 'Submit Request',
          isLoading: _isSubmitting,
          isFullWidth: false,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}

