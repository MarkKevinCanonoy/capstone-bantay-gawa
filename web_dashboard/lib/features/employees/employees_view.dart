import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/toast_notification.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/repository_provider.dart';

class EmployeesView extends ConsumerStatefulWidget {
  const EmployeesView({super.key});

  @override
  ConsumerState<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends ConsumerState<EmployeesView> {
  String _selectedAreaFilter = 'all';

  void _showAddEmployeeDialog() {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final usernameController = TextEditingController();
    final contactController = TextEditingController();
    UserRole role = UserRole.worker;
    String areaId = 'area-1';
    String areaName = 'Ormoc City Hall Zone';

    ConfirmationDialog.show(
      context,
      title: 'Register New Personnel',
      message: 'Create a system account for a field worker or supervisor.',
      confirmLabel: 'Register Account',
      contentWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('First Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(controller: firstController, decoration: const InputDecoration(hintText: 'First name')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(controller: lastController, decoration: const InputDecoration(hintText: 'Last name')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Username', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: usernameController, decoration: const InputDecoration(hintText: 'e.g. worker_dan')),
          const SizedBox(height: 12),
          const Text('Contact Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: contactController, decoration: const InputDecoration(hintText: '+63 918 000 0000')),
          const SizedBox(height: 12),
          const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<UserRole>(
            initialValue: role,
            items: const [
              DropdownMenuItem(value: UserRole.worker, child: Text('Field Worker')),
              DropdownMenuItem(value: UserRole.supervisor, child: Text('Field Supervisor')),
            ],
            onChanged: (val) {
              if (val != null) role = val;
            },
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 12),
          const Text('Assigned Work Area', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: areaId,
            items: const [
              DropdownMenuItem(value: 'area-1', child: Text('Ormoc City Hall Zone')),
              DropdownMenuItem(value: 'area-2', child: Text('Ormoc Public Market')),
              DropdownMenuItem(value: 'area-3', child: Text('Ormoc Bus Terminal')),
              DropdownMenuItem(value: 'area-4', child: Text('Centennial Park Zone')),
            ],
            onChanged: (val) {
              if (val != null) {
                areaId = val;
                areaName = val == 'area-1'
                    ? 'Ormoc City Hall Zone'
                    : val == 'area-2'
                        ? 'Ormoc Public Market'
                        : val == 'area-3'
                            ? 'Ormoc Bus Terminal'
                            : 'Centennial Park Zone';
              }
            },
            decoration: const InputDecoration(),
          ),
        ],
      ),
      onConfirm: () async {
        if (firstController.text.trim().isEmpty || lastController.text.trim().isEmpty) return;
        final newUser = UserModel(
          userId: 'user-w-${DateTime.now().millisecondsSinceEpoch}',
          username: usernameController.text.trim().isNotEmpty
              ? usernameController.text.trim()
              : '${firstController.text.trim().toLowerCase()}_${lastController.text.trim().toLowerCase()}',
          firstName: firstController.text.trim(),
          lastName: lastController.text.trim(),
          contactNumber: contactController.text.trim(),
          role: role,
          status: 'active',
          assignedAreaId: areaId,
          assignedAreaName: areaName,
          creditScore: 100,
        );
        await ref.read(dataRepositoryProvider).addUser(newUser);
        ref.invalidate(employeesProvider);
        if (mounted) {
          ToastNotification.show(context, message: 'Personnel ${newUser.fullName} registered successfully!', type: ToastType.success);
        }
      },
    );
  }

  void _showEmployeeDetailsModal(UserModel emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryNavy,
              child: Text(emp.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('@${emp.username} • ${emp.roleDisplayName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Assigned Area', emp.assignedAreaName ?? 'Unassigned'),
              _buildDetailRow('Contact Number', emp.contactNumber),
              _buildDetailRow('Work Schedule', emp.schedule),
              _buildDetailRow('Account Status', emp.status.toUpperCase()),
              const SizedBox(height: 12),
              const Text('Star Performance Credit Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: emp.creditScore >= 80
                      ? AppColors.successBg
                      : emp.creditScore >= 50
                          ? AppColors.warningBg
                          : AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${emp.creditScore} / 100 Points',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: emp.creditScore >= 80
                            ? AppColors.successText
                            : emp.creditScore >= 50
                                ? AppColors.warningText
                                : AppColors.dangerText,
                      ),
                    ),
                    Text(
                      emp.creditScore >= 80
                          ? 'OPTIMAL STANDING'
                          : emp.creditScore >= 50
                              ? 'ATTENTION NEEDED'
                              : 'CRITICAL DISCIPLINARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: emp.creditScore >= 80
                            ? AppColors.successText
                            : emp.creditScore >= 50
                                ? AppColors.warningText
                                : AppColors.dangerText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final globalSearch = ref.watch(globalSearchProvider).toLowerCase();
    final employees = employeesAsync.value ?? [];

    final filteredEmployees = employees.where((emp) {
      final matchesSearch = emp.fullName.toLowerCase().contains(globalSearch) ||
          emp.username.toLowerCase().contains(globalSearch) ||
          (emp.assignedAreaName?.toLowerCase().contains(globalSearch) ?? false);
      final matchesArea = _selectedAreaFilter == 'all' || emp.assignedAreaId == _selectedAreaFilter;
      return matchesSearch && matchesArea;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personnel Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    currentUser.role == UserRole.admin
                        ? 'Manage all field workers, supervisors, face registrations, and credit scores.'
                        : 'Field staff assigned to your supervisory sector.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              if (currentUser.role == UserRole.admin)
                AppButton(
                  label: '+ Add Personnel',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: _showAddEmployeeDialog,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Bar
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Text('Filter by Area:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedAreaFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Work Areas')),
                    DropdownMenuItem(value: 'area-1', child: Text('Ormoc City Hall Zone')),
                    DropdownMenuItem(value: 'area-2', child: Text('Ormoc Public Market')),
                    DropdownMenuItem(value: 'area-3', child: Text('Ormoc Bus Terminal')),
                    DropdownMenuItem(value: 'area-4', child: Text('Centennial Park Zone')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAreaFilter = val);
                  },
                ),
                const Spacer(),
                Text('${filteredEmployees.length} registered personnel', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Directory Table
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('PERSONNEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ROLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ASSIGNED AREA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('SCHEDULE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CREDIT SCORE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                  rows: filteredEmployees.map((emp) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryNavy,
                                child: Text(emp.initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                  Text(emp.contactNumber, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            label: emp.roleDisplayName,
                            type: emp.role == UserRole.admin
                                ? BadgeType.optimal
                                : emp.role == UserRole.supervisor
                                    ? BadgeType.neutral
                                    : BadgeType.neutral,
                          ),
                        ),
                        DataCell(Text(emp.assignedAreaName ?? 'Unassigned', style: const TextStyle(fontSize: 13))),
                        DataCell(Text(emp.schedule, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: emp.creditScore >= 80
                                  ? AppColors.successBg
                                  : emp.creditScore >= 50
                                      ? AppColors.warningBg
                                      : AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${emp.creditScore}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: emp.creditScore >= 80
                                    ? AppColors.successText
                                    : emp.creditScore >= 50
                                        ? AppColors.warningText
                                        : AppColors.dangerText,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          StatusBadge(
                            label: emp.status,
                            type: emp.status == 'active' ? BadgeType.success : BadgeType.danger,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.accentBlue),
                                tooltip: 'View Profile',
                                onPressed: () => _showEmployeeDetailsModal(emp),
                              ),
                              if (currentUser.role == UserRole.admin)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.brightRed),
                                  tooltip: 'Delete User',
                                  onPressed: () {
                                    ConfirmationDialog.show(
                                      context,
                                      title: 'Delete User Account',
                                      message: 'Are you sure you want to delete ${emp.fullName}? This will revoke system access.',
                                      confirmLabel: 'Delete',
                                      confirmVariant: ButtonVariant.danger,
                                      onConfirm: () async {
                                        await ref.read(dataRepositoryProvider).deleteUser(emp.userId);
                                        ref.invalidate(employeesProvider);
                                        if (context.mounted) {
                                          ToastNotification.show(context, message: 'User ${emp.fullName} removed.', type: ToastType.info);
                                        }
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
