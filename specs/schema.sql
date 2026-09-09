-- Enable PostGIS for spatial data
CREATE EXTENSION IF NOT EXISTS postgis;

-- Roles Table
CREATE TABLE roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE, -- 'Admin', 'Field Supervisor', 'Field Worker'
    description TEXT
);

-- Users Table
CREATE TABLE users (
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

-- Work Areas (Geofences)
CREATE TABLE work_areas (
    workarea_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    supervisor_id UUID REFERENCES users(user_id),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Work Area Assignments
CREATE TABLE work_area_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workarea_id UUID NOT NULL REFERENCES work_areas(workarea_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    is_active BOOLEAN DEFAULT true
);

-- Attendance Table
CREATE TABLE attendance (
    attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    workarea_id UUID REFERENCES work_areas(workarea_id),
    action_type VARCHAR(20) NOT NULL, -- 'time-in', 'break-in', 'break-out', 'time-out'
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    gps_lat FLOAT8 NOT NULL,
    gps_lng FLOAT8 NOT NULL,
    image_url TEXT,
    face_match BOOLEAN DEFAULT false,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Location Tracking Table
CREATE TABLE location_tracking (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    attendance_id UUID REFERENCES attendance(attendance_id),
    gps_lat FLOAT8 NOT NULL,
    gps_lng FLOAT8 NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    is_last_seen BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Accomplishment Reports
CREATE TABLE accomplishments (
    accomplishment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    workarea_id UUID REFERENCES work_areas(workarea_id),
    image_url TEXT NOT NULL,
    captured_date DATE NOT NULL,
    captured_time TIME NOT NULL,
    captured_lat FLOAT8 NOT NULL,
    captured_lng FLOAT8 NOT NULL,
    message TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'denied'
    approved_by UUID REFERENCES users(user_id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Leave Requests
CREATE TABLE leave_requests (
    leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    type VARCHAR(50) NOT NULL, -- 'emergency', 'sick', 'vacation', 'other'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'denied'
    admin_decision UUID REFERENCES users(user_id),
    decision_at TIMESTAMP WITH TIME ZONE,
    is_synced BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Credit Balance & History
CREATE TABLE credit_balance (
    balance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(user_id),
    current_score INTEGER DEFAULT 100,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE credit_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    change_amount INTEGER NOT NULL,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Notifications & Alerts
CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES users(user_id),
    receiver_id UUID REFERENCES users(user_id),
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'announcement', 'confidential', 'alert'
    is_read BOOLEAN DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    type VARCHAR(50) NOT NULL, -- 'consecutive_absences', 'breach', 'score_warning'
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES users(user_id)
);

-- Incident Worker Reports
CREATE TABLE worker_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(user_id),
    reported_id UUID NOT NULL REFERENCES users(user_id),
    issue_type VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Schedules
CREATE TABLE schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    days VARCHAR(50) NOT NULL, -- Comma-separated e.g. 'Mon,Tue,Wed,Thu,Fri'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Audit Logs
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id),
    action VARCHAR(20) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);