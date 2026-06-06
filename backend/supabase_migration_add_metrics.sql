-- OPTIONAL: Run this ONLY if you want to add the missing dashboard columns
-- Current health_metrics table has: blood_pressure, blood_sugar, heart_rate, sleep_hours, steps, body_temp
-- This migration adds: spo2, resp_rate, weight, bmi

ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS spo2 TEXT DEFAULT '98';
ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS resp_rate TEXT DEFAULT '16';
ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS weight TEXT DEFAULT '68';
ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS bmi TEXT DEFAULT '22.4';
ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
