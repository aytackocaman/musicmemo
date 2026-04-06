-- Daily Challenge scores table
CREATE TABLE daily_challenge_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  score INTEGER NOT NULL,
  moves INTEGER NOT NULL,
  time_seconds INTEGER NOT NULL,
  category TEXT NOT NULL,
  grid_size TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Index for leaderboard queries (top scores per date)
CREATE INDEX idx_daily_challenge_date_score
  ON daily_challenge_scores(date, score DESC);

-- Enable Row Level Security
ALTER TABLE daily_challenge_scores ENABLE ROW LEVEL SECURITY;

-- Users can insert their own daily score
CREATE POLICY "Users can insert own daily score"
  ON daily_challenge_scores FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Anyone authenticated can view all daily scores (leaderboard)
CREATE POLICY "Anyone can view daily scores"
  ON daily_challenge_scores FOR SELECT
  USING (true);
