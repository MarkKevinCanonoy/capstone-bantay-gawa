# Project Overview: BantayGawaMobile
Intelligent mobile workforce attendance verification system for ENRO Ormoc City.
Tech Stack: Flutter (Mobile Android + Web), Supabase, PostGIS, SQLite, flutter_map + OpenStreetMap, Firebase Cloud Messaging.

# Core Development Rules
1. Role & Design Parity:
   - The Admin prototype look is the single visual standard.
   - The Supervisor view must inherit the exact same color scheme, typography, card shapes, and layout style as the Admin UI.
   - The only difference between roles is feature access and data visibility, NOT visual styling.

2. Source of Truth:
   - Database tables, column names, and types must strictly follow `specs/schema.sql`.
   - Feature permissions and restrictions must strictly follow `specs/roles_matrix.md`.
   - UI styling and React-to-Flutter component mapping must follow `specs/design_system.md`.

3. Workspace Architecture:
   - `mobile_app/`: Target is Android field workers and mobile supervisors. Use offline SQLite caching, MobileFaceNet/TFLite, and camera packages here.
   - `web_dashboard/`: Target is Admin and Supervisor web browsers. Never import native-only plugins (`dart:io`, `sqflite`, `camera`) in `web_dashboard/`.

4. Offline & Metadata Rules:
   - Attendance and proof photos taken offline must save to local SQLite with `is_synced = false`.
   - Proof photos must have timestamp and GPS coordinates burned directly into the image bytes using the `image` package before upload.