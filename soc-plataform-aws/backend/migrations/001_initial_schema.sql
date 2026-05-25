-- SOC Platform AWS - Schema PostgreSQL 15
-- Migration: 001_initial_schema.sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- Tenants (multi-tenancy)
-- ============================================================
CREATE TABLE tenants (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name       VARCHAR(255) NOT NULL,
    slug       VARCHAR(100) UNIQUE NOT NULL,
    status     VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenants_slug ON tenants(slug);
CREATE INDEX idx_tenants_status ON tenants(status);

-- ============================================================
-- Users
-- ============================================================
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id     UUID REFERENCES tenants(id) ON DELETE CASCADE,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name          VARCHAR(255) NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'analyst',
    mfa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    mfa_secret    VARCHAR(255),
    last_login_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_role_check CHECK (role IN ('admin', 'analyst', 'viewer'))
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);

-- ============================================================
-- Security events (high-volume, partitioned by month)
-- ============================================================
CREATE TABLE security_events (
    id          UUID NOT NULL DEFAULT uuid_generate_v4(),
    tenant_id   UUID NOT NULL,
    source      VARCHAR(50) NOT NULL,
    severity    VARCHAR(20) NOT NULL,
    rule_id     VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    raw         JSONB NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, occurred_at),
    CONSTRAINT events_severity_check CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT events_source_check CHECK (source IN ('wazuh', 'falco', 'suricata', 'cloudtrail', 'guardduty'))
) PARTITION BY RANGE (occurred_at);

CREATE INDEX idx_events_tenant_time ON security_events(tenant_id, occurred_at DESC);
CREATE INDEX idx_events_severity ON security_events(severity, occurred_at DESC);
CREATE INDEX idx_events_source ON security_events(source, occurred_at DESC);
CREATE INDEX idx_events_raw_gin ON security_events USING GIN (raw);

-- Initial partitions
CREATE TABLE security_events_2026_05 PARTITION OF security_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE security_events_2026_06 PARTITION OF security_events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- ============================================================
-- Alerts (correlated events)
-- ============================================================
CREATE TABLE alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    title           VARCHAR(500) NOT NULL,
    severity        VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'open',
    event_ids       UUID[] NOT NULL,
    assigned_to     UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by UUID REFERENCES users(id),
    resolved_at     TIMESTAMPTZ,
    resolved_by     UUID REFERENCES users(id),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT alerts_status_check CHECK (status IN ('open', 'acknowledged', 'investigating', 'resolved', 'false_positive'))
);

CREATE INDEX idx_alerts_tenant_status ON alerts(tenant_id, status);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_assigned ON alerts(assigned_to);

-- ============================================================
-- Compliance checks
-- ============================================================
CREATE TABLE compliance_checks (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    framework   VARCHAR(50) NOT NULL,
    control_id  VARCHAR(100) NOT NULL,
    status      VARCHAR(20) NOT NULL,
    details     JSONB,
    checked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT compliance_framework_check CHECK (framework IN ('CIS', 'NIST', 'PCI-DSS', 'LGPD', 'ISO27001')),
    CONSTRAINT compliance_status_check CHECK (status IN ('pass', 'fail', 'skip', 'manual'))
);

CREATE INDEX idx_compliance_tenant ON compliance_checks(tenant_id, framework);

-- ============================================================
-- Audit log
-- ============================================================
CREATE TABLE audit_log (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID REFERENCES users(id),
    action     VARCHAR(100) NOT NULL,
    resource   VARCHAR(255) NOT NULL,
    metadata   JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_action ON audit_log(action, created_at DESC);

-- ============================================================
-- Seed data
-- ============================================================
INSERT INTO tenants (name, slug) VALUES
    ('Demo Tenant', 'demo'),
    ('SENAI Lab', 'senai-lab');

-- Default admin (password: changeMe!)
-- bcrypt hash for 'changeMe!' with 10 rounds
INSERT INTO users (tenant_id, email, password_hash, name, role) VALUES
    ((SELECT id FROM tenants WHERE slug='demo'),
     'admin@soc.local',
     '$2b$10$rHvL5pJ8gZx9YkVqXfYzMu5C8gK0fY9wQ8X2mD3J4nR5T6vY7zW8e',
     'Admin', 'admin');
