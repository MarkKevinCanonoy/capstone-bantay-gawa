-- ==============================================================================
-- BANTAYGAWA MOBILE - SUPABASE INITIAL SETUP SCRIPT (PHASE 1)
-- Environment: ENRO Ormoc City
-- Includes: PostGIS, 15 Tables, Geofencing RPC, Storage Buckets, and Seed Data
-- ==============================================================================

-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. CREATE ROLES TABLE
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE, -- 'Admin', 'Field Supervisor', 'Field Worker'
    description TEXT
);

-- 3. CREATE USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(20),
    qr_token VARCHAR(100) UNIQUE,
    role_id UUID NOT NULL REFERENCES roles(role_id),
    face_embedding TEXT,
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'inactive', 'pending'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. WORK AREAS (GEOFENCES)
CREATE TABLE IF NOT EXISTS work_areas (
    workarea_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    supervisor_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 5. WORK AREA ASSIGNMENTS
CREATE TABLE IF NOT EXISTS work_area_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workarea_id UUID NOT NULL REFERENCES work_areas(workarea_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    is_active BOOLEAN DEFAULT true
);

-- 6. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    workarea_id UUID REFERENCES work_areas(workarea_id) ON DELETE SET NULL,
    action_type VARCHAR(20) NOT NULL, -- 'time-in', 'break-in', 'break-out', 'time-out'
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    gps_lat FLOAT8 NOT NULL,
    gps_lng FLOAT8 NOT NULL,
    image_url TEXT,
    face_match BOOLEAN DEFAULT false,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 7. LOCATION TRACKING TABLE
CREATE TABLE IF NOT EXISTS location_tracking (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    attendance_id UUID REFERENCES attendance(attendance_id) ON DELETE CASCADE,
    gps_lat FLOAT8 NOT NULL,
    gps_lng FLOAT8 NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    is_last_seen BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 8. ACCOMPLISHMENT REPORTS
CREATE TABLE IF NOT EXISTS accomplishments (
    accomplishment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    workarea_id UUID REFERENCES work_areas(workarea_id) ON DELETE SET NULL,
    image_url TEXT NOT NULL,
    captured_date DATE NOT NULL,
    captured_time TIME NOT NULL,
    captured_lat FLOAT8 NOT NULL,
    captured_lng FLOAT8 NOT NULL,
    message TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'denied'
    approved_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 9. LEAVE REQUESTS
CREATE TABLE IF NOT EXISTS leave_requests (
    leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'emergency', 'sick', 'vacation', 'other'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'denied'
    admin_decision UUID REFERENCES users(user_id) ON DELETE SET NULL,
    decision_at TIMESTAMP WITH TIME ZONE,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 10. CREDIT BALANCE & HISTORY
CREATE TABLE IF NOT EXISTS credit_balance (
    balance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    current_score INTEGER DEFAULT 100,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS credit_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    change_amount INTEGER NOT NULL,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 11. NOTIFICATIONS & ALERTS
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'announcement', 'confidential', 'alert'
    is_read BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'consecutive_absences', 'breach', 'score_warning'
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES users(user_id) ON DELETE SET NULL
);

-- 12. INCIDENT WORKER REPORTS
CREATE TABLE IF NOT EXISTS worker_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    issue_type VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'settled_locally', 'escalated'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 13. SCHEDULES
CREATE TABLE IF NOT EXISTS schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    days VARCHAR(50) NOT NULL, -- 'Mon,Tue,Wed,Thu,Fri'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 14. AUDIT LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ==============================================================================
-- 15. POSTGIS SPATIAL HELPER FUNCTIONS
-- ==============================================================================

-- Function to check if a GPS lat/lng coordinate is inside a given work area
CREATE OR REPLACE FUNCTION is_point_in_work_area(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_workarea_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_inside BOOLEAN;
BEGIN
    SELECT ST_Contains(
        geometry,
        ST_SetSRID(ST_Point(p_lng, p_lat), 4326)
    ) INTO v_inside
    FROM work_areas
    WHERE workarea_id = p_workarea_id;

    RETURN COALESCE(v_inside, false);
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 16. SUPABASE STORAGE BUCKETS CONFIGURATION (FREE TIER SAFE: 2MB LIMIT)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('proof_images', 'proof_images', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('selfies', 'selfies', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('leave_attachments', 'leave_attachments', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('worker_reports', 'worker_reports', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Storage bucket access policies
CREATE POLICY "Public Read Access on Storage" ON storage.objects
    FOR SELECT USING (bucket_id IN ('proof_images', 'selfies', 'leave_attachments', 'worker_reports'));

CREATE POLICY "Allow Uploads to Storage" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id IN ('proof_images', 'selfies', 'leave_attachments', 'worker_reports'));

-- ==============================================================================
-- 17. SEED DATA (ORMOC CITY INITIAL DEPLOYMENT)
-- ==============================================================================

-- A. Insert Roles
INSERT INTO roles (role_id, name, description) VALUES
    ('00000000-0000-0000-0000-000000000001', 'Admin', 'Overall system administrator with full access to all features'),
    ('00000000-0000-0000-0000-000000000002', 'Field Supervisor', 'Field officer assigned to monitor workers in designated areas'),
    ('00000000-0000-0000-0000-000000000003', 'Field Worker', 'Frontline worker (street sweeper, green crew)')
ON CONFLICT (name) DO NOTHING;

-- B. Insert Users (Admin, Supervisor, and Workers)
INSERT INTO users (user_id, username, first_name, last_name, contact_number, qr_token, role_id, status) VALUES
    ('11111111-1111-1111-1111-111111111111', 'admin_enro', 'Roberto', 'Del Rosario', '+63 917 111 0001', 'QR-ADM-001', '00000000-0000-0000-0000-000000000001', 'active'),
    ('22222222-2222-2222-2222-222222222222', 'sup_juan', 'Juan', 'Santos', '+63 917 222 0002', 'QR-SUP-001', '00000000-0000-0000-0000-000000000002', 'active'),
    ('33333333-3333-3333-3333-333333333333', 'worker_maria', 'Maria', 'Santos', '+63 917 333 0003', 'QR-WRK-001', '00000000-0000-0000-0000-000000000003', 'active'),
    ('44444444-4444-4444-4444-444444444444', 'worker_pedro', 'Pedro', 'Penduko', '+63 917 444 0004', 'QR-WRK-002', '00000000-0000-0000-0000-000000000003', 'active')
ON CONFLICT (username) DO NOTHING;

-- C. Insert Ormoc Work Areas (with PostGIS Polygons)
INSERT INTO work_areas (workarea_id, name, supervisor_id, description, geometry) VALUES
    (
        'aaaa1111-1111-1111-1111-111111111111',
        'Ormoc City Hall Zone',
        '22222222-2222-2222-2222-222222222222',
        'Administrative perimeter and executive building grounds.',
        ST_GeomFromText('POLYGON((124.6062 11.0058, 124.6085 11.0068, 124.6092 11.0045, 124.6068 11.0038, 124.6062 11.0058))', 4326)
    ),
    (
        'bbbb2222-2222-2222-2222-222222222222',
        'Ormoc Public Market',
        '22222222-2222-2222-2222-222222222222',
        'Commercial wet and dry market sanitation sector.',
        ST_GeomFromText('POLYGON((124.6030 11.0080, 124.6055 11.0095, 124.6070 11.0075, 124.6045 11.0060, 124.6030 11.0080))', 4326)
    )
ON CONFLICT (workarea_id) DO NOTHING;

-- D. Assign Workers to Work Areas
INSERT INTO work_area_assignments (workarea_id, user_id, is_active) VALUES
    ('aaaa1111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', true),
    ('bbbb2222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', true)
ON CONFLICT DO NOTHING;

-- E. Initial Credit Balances (100 base score)
INSERT INTO credit_balance (user_id, current_score) VALUES
    ('33333333-3333-3333-3333-333333333333', 95),
    ('44444444-4444-4444-4444-444444444444', 68)
ON CONFLICT (user_id) DO NOTHING;
