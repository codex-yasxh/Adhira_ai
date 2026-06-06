CREATE TABLE IF NOT EXISTS health_metrics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blood_pressure TEXT DEFAULT '120/80',
  blood_sugar TEXT DEFAULT '95',
  heart_rate TEXT DEFAULT '72',
  sleep_hours TEXT DEFAULT '7',
  steps TEXT DEFAULT '10000',
  body_temp TEXT DEFAULT '98.6',
  spo2 TEXT DEFAULT '98',
  resp_rate TEXT DEFAULT '16',
  weight TEXT DEFAULT '68',
  bmi TEXT DEFAULT '22.4',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

ALTER TABLE health_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own metrics" ON health_metrics
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own metrics" ON health_metrics
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own metrics" ON health_metrics
  FOR UPDATE USING (auth.uid() = user_id);
