import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/user_model.dart';
import '../../data/models/leave_request_model.dart';

class OfficialReportPdfHelper {
  static pw.MemoryImage? _cachedLogo;

  static const PdfColor primaryNavy = PdfColor.fromInt(0xFF08284B);
  static const PdfColor forestGreen = PdfColor.fromInt(0xFF167346);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor bgZebra = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor bgCard = PdfColor.fromInt(0xFFF1F5F9);

  // Status colors
  static const PdfColor statusApprovedBg = PdfColor.fromInt(0xFFDCFCE7);
  static const PdfColor statusApprovedText = PdfColor.fromInt(0xFF166534);
  static const PdfColor statusPendingBg = PdfColor.fromInt(0xFFFEF3C7);
  static const PdfColor statusPendingText = PdfColor.fromInt(0xFF92400E);
  static const PdfColor statusDeniedBg = PdfColor.fromInt(0xFFFEE2E2);
  static const PdfColor statusDeniedText = PdfColor.fromInt(0xFF991B1B);

  static Future<pw.MemoryImage?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      _cachedLogo = pw.MemoryImage(bytes.buffer.asUint8List());
      return _cachedLogo;
    } catch (_) {
      return null;
    }
  }

  /// Official Letterhead
  static pw.Widget _buildLetterhead(pw.MemoryImage? logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 52,
                height: 52,
                margin: const pw.EdgeInsets.only(right: 14),
                child: pw.Image(logoImage),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPUBLIC OF THE PHILIPPINES',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'CITY GOVERNMENT OF ORMOC',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'CITY ENVIRONMENT AND NATURAL RESOURCES OFFICE (ENRO)',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: forestGreen,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'BantayGawa - ENRO Ormoc City Portal',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: primaryNavy),
        pw.SizedBox(height: 1.5),
        pw.Container(height: 1, color: forestGreen),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Official Audit Metadata Block
  static pw.Widget _buildMetadataBox({
    required String title,
    required UserModel generatedBy,
    required String dateRangeLabel,
    required String sectorLabel,
    required int totalRecords,
    String? subtitle,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy | hh:mm a').format(now);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgCard,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderLight, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryNavy),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
          ],
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _metaField('Reporting Scope', dateRangeLabel),
              ),
              pw.Expanded(
                child: _metaField('Sector Scope', sectorLabel),
              ),
              pw.Expanded(
                child: _metaField('Generated By', '${generatedBy.fullName} (${generatedBy.roleDisplayName})'),
              ),
              pw.Expanded(
                child: _metaField('Date Generated', dateStr),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: primaryNavy,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  '$totalRecords Records',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: textMuted)),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      ],
    );
  }

  /// Official Certification & Tripartite Signatories
  static pw.Widget _buildSignatories({
    required UserModel generatedBy,
    String? supervisorName,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(now);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // 1. Prepared By
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PREPARED BY:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted)),
                  pw.SizedBox(height: 28),
                  pw.Container(height: 1, color: textDark),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    generatedBy.fullName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                  pw.Text(
                    generatedBy.role == UserRole.admin ? 'System Administrator / Head Clerk' : 'Field Operations Supervisor',
                    style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                  ),
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
                ],
              ),
            ),
            pw.SizedBox(width: 24),

            // 2. Verified / Endorsed By
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('VERIFIED / REVIEWED BY:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted)),
                  pw.SizedBox(height: 28),
                  pw.Container(height: 1, color: textDark),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    (supervisorName ?? 'FIELD OPERATIONS SUPERVISOR').toUpperCase(),
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                  pw.Text(
                    'Field Operations Supervisor',
                    style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                  ),
                  pw.Text('City ENRO Ormoc', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
                ],
              ),
            ),
            pw.SizedBox(width: 24),

            // 3. Approved By
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('APPROVED BY:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted)),
                  pw.SizedBox(height: 28),
                  pw.Container(height: 1, color: textDark),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'CITY ENRO DEPARTMENT HEAD',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
                  ),
                  pw.Text(
                    'City ENRO Department Head',
                    style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                  ),
                  pw.Text('LGU Ormoc City', style: const pw.TextStyle(fontSize: 7, color: textMuted)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Official Multi-page Footer
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderLight, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CONFIDENTIAL & OFFICIAL LGU ENRO DOCUMENT | BANTAYGAWA AUDIT COMPLIANCE',
            style: const pw.TextStyle(fontSize: 7, color: textMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryNavy),
          ),
        ],
      ),
    );
  }

  /// Generate Official Leave Requests PDF
  static Future<Uint8List> generateLeavesPdf({
    required List<LeaveRequestModel> leaves,
    required UserModel generatedBy,
    required String dateRangeLabel,
    required String sectorLabel,
  }) async {
    final logo = await _loadLogo();
    final pdf = pw.Document();

    final headers = [
      'Ref ID',
      'Personnel Name',
      'Work Sector',
      'Filing Type',
      'Absence Period',
      'Reason / Justification',
      'Supervisor Endorsement',
      'Status',
    ];

    final dataRows = leaves.map((l) {
      final period = '${l.startDate}${l.endDate != l.startDate ? " to ${l.endDate}" : ""}';
      final reason = l.reason.length > 40 ? '${l.reason.substring(0, 38)}...' : l.reason;
      final endorsement = (l.supervisorEndorsement != null && l.supervisorEndorsement!.trim().isNotEmpty)
          ? (l.supervisorEndorsement!.length > 30 ? '${l.supervisorEndorsement!.substring(0, 28)}...' : l.supervisorEndorsement!)
          : 'None';
      final refId = l.leaveId.length > 8 ? l.leaveId.substring(0, 8).toUpperCase() : l.leaveId.toUpperCase();

      return [
        refId,
        l.workerName,
        l.areaName,
        l.type,
        period,
        reason,
        endorsement,
        l.status.toUpperCase(),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildLetterhead(logo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildMetadataBox(
            title: 'Official Leave Request & Workforce Absence Audit Report',
            generatedBy: generatedBy,
            dateRangeLabel: dateRangeLabel,
            sectorLabel: sectorLabel,
            totalRecords: leaves.length,
            subtitle: 'Compiled absence filings, medical certifications, supervisor endorsements, and executive approvals.',
          ),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryNavy),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: bgZebra),
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0), // Ref ID
              1: const pw.FlexColumnWidth(2.0), // Name
              2: const pw.FlexColumnWidth(1.8), // Sector
              3: const pw.FlexColumnWidth(1.4), // Type
              4: const pw.FlexColumnWidth(1.8), // Period
              5: const pw.FlexColumnWidth(2.2), // Reason
              6: const pw.FlexColumnWidth(1.8), // Endorsement
              7: const pw.FlexColumnWidth(1.2), // Status
            },
          ),
          _buildSignatories(generatedBy: generatedBy),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate Generic Audit PDF (Attendance, Area Performance, Worker Performance, Accomplishments)
  static Future<Uint8List> generateAuditPdf({
    required String reportTitle,
    required List<String> headers,
    required List<List<String>> dataRows,
    required UserModel generatedBy,
    required String dateRangeLabel,
    required String sectorLabel,
    String? subtitle,
    Map<int, pw.TableColumnWidth>? columnWidths,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final logo = await _loadLogo();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildLetterhead(logo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildMetadataBox(
            title: reportTitle,
            generatedBy: generatedBy,
            dateRangeLabel: dateRangeLabel,
            sectorLabel: sectorLabel,
            totalRecords: dataRows.length,
            subtitle: subtitle,
          ),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: primaryNavy),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: textDark),
            cellAlignment: pw.Alignment.centerLeft,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: bgZebra),
            border: pw.TableBorder.all(color: borderLight, width: 0.5),
            columnWidths: columnWidths,
          ),
          _buildSignatories(generatedBy: generatedBy),
        ],
      ),
    );

    return pdf.save();
  }
}
