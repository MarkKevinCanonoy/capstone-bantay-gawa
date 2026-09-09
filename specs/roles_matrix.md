# Role Access Control Matrix

### 1. Admin (Web Dashboard + Mobile)
- Full system authority.
- User Management: Create, edit, delete users; register face embeddings; generate printable QR codes.
- Work Area Management: Draw polygon geofences on OpenStreetMap; assign supervisors and workers.
- Approvals: Final authority to approve or deny leave requests (denial requires a reason). Review accomplishment reports.
- GIS Map: View all areas, active workers, live locations, and breach alerts across Ormoc City.
- Reports & Alerts: Generate and export system-wide attendance, area performance, and worker reports (PDF/Excel). Manage alerts (consecutive absences, credit drops).
- Notifications: Send general announcements or private confidential notifications to any user.

### 2. Field Supervisor (Web Dashboard + Mobile)
- Scoped to assigned work areas only.
- Worker Oversight: View attendance summary, profiles, and live status of workers assigned to their areas.
- Approvals: Review, approve, or deny daily accomplishment proofs for assigned areas.
- Leave: View leave requests from assigned workers (read-only; only Admin can approve/deny).
- GIS Map: View worker markers and geofences for assigned work areas only.
- Reports: Generate and export attendance/performance reports for their assigned areas.
- Incident Reporting: Submit issue reports with attached photo evidence directly to Admin.

### 3. Field Worker (Mobile App Only)
- Minimalist, mobile-first interface with large touch targets (>44dp).
- Authentication: Scan ID QR code for one-time setup; session persists permanently afterwards.
- Attendance: Log Time-in, Break-in, Break-out, Time-out. Requires on-device face recognition match + GPS inside assigned geofence boundary.
- Accomplishments: Upload daily accomplishment photos. Automatically burns timestamp and lat/long overlay onto the image and embeds EXIF metadata.
- Offline Capability: If no internet connection exists, attendance logs and photos save locally to SQLite and automatically push to Supabase upon reconnection.
- Leave & Score: Submit leave requests with reason/proof. View star performance credit score (Green 80-100, Yellow 50-70, Red 10-40) and history.