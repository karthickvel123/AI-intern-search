-- Enable the pgvector extension for AI embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Helper function to automatically update `updated_at` timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1. PROFILES TABLE
-- Stores user's MasterProfile JSON, preferences, and 768-dim resume embedding
-- ============================================================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE, -- Maps to Supabase auth.users if auth is used
    master_profile JSONB NOT NULL DEFAULT '{}'::jsonb,
    target_roles TEXT[] DEFAULT '{}',
    preferred_locations TEXT[] DEFAULT '{}',
    remote_preference BOOLEAN DEFAULT TRUE,
    resume_embedding VECTOR(768),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- Trigger for profiles updated_at
DROP TRIGGER IF EXISTS set_profiles_updated_at ON profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for profiles
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles (user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_master_profile ON profiles USING gin (master_profile);
CREATE INDEX IF NOT EXISTS idx_profiles_resume_embedding 
    ON profiles USING hnsw (resume_embedding vector_cosine_ops);


-- ============================================================================
-- 2. JOBS TABLE
-- Stores normalized job listings with metadata and 768-dim job embedding
-- ============================================================================
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    company TEXT NOT NULL,
    location TEXT,
    is_remote BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT NOT NULL,
    apply_url TEXT,
    source TEXT,
    posted_at TIMESTAMPTZ,
    ghost_job_flag BOOLEAN NOT NULL DEFAULT FALSE,
    job_embedding VECTOR(768),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- Trigger for jobs updated_at
DROP TRIGGER IF EXISTS set_jobs_updated_at ON jobs;
CREATE TRIGGER set_jobs_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for jobs
CREATE INDEX IF NOT EXISTS idx_jobs_company ON jobs (company);
CREATE INDEX IF NOT EXISTS idx_jobs_is_remote ON jobs (is_remote);
CREATE INDEX IF NOT EXISTS idx_jobs_posted_at ON jobs (posted_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_ghost_flag ON jobs (ghost_job_flag);
CREATE INDEX IF NOT EXISTS idx_jobs_job_embedding 
    ON jobs USING hnsw (job_embedding vector_cosine_ops);


-- ============================================================================
-- 3. MATCHES TABLE
-- Links a user profile to a job with AI match score, skills, and rationale
-- ============================================================================
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    match_score NUMERIC(5, 2) NOT NULL CHECK (match_score >= 0 AND match_score <= 100),
    matched_skills TEXT[] DEFAULT '{}',
    missing_skills TEXT[] DEFAULT '{}',
    match_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    CONSTRAINT uq_matches_profile_job UNIQUE (profile_id, job_id)
);

-- Trigger for matches updated_at
DROP TRIGGER IF EXISTS set_matches_updated_at ON matches;
CREATE TRIGGER set_matches_updated_at
    BEFORE UPDATE ON matches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for matches
CREATE INDEX IF NOT EXISTS idx_matches_profile_id ON matches (profile_id);
CREATE INDEX IF NOT EXISTS idx_matches_job_id ON matches (job_id);
CREATE INDEX IF NOT EXISTS idx_matches_score ON matches (profile_id, match_score DESC);


-- ============================================================================
-- 4. APPLICATIONS TABLE
-- Tracks application progress stages, tailored resume bullets, and outreach
-- ============================================================================
CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'saved' CHECK (status IN ('saved', 'applied', 'interview', 'offer', 'rejected')),
    tailored_bullets_json JSONB DEFAULT '{}'::jsonb,
    referral_dm TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    CONSTRAINT uq_applications_profile_job UNIQUE (profile_id, job_id)
);

-- Trigger for applications updated_at
DROP TRIGGER IF EXISTS set_applications_updated_at ON applications;
CREATE TRIGGER set_applications_updated_at
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for applications
CREATE INDEX IF NOT EXISTS idx_applications_profile_id ON applications (profile_id);
CREATE INDEX IF NOT EXISTS idx_applications_job_id ON applications (job_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications (profile_id, status);


-- ============================================================================
-- RPC FUNCTION: Semantic Job Search using Cosine Similarity
-- ============================================================================
CREATE OR REPLACE FUNCTION match_jobs(
    query_embedding VECTOR(768),
    match_threshold FLOAT DEFAULT 0.5,
    match_count INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    external_id TEXT,
    title TEXT,
    company TEXT,
    location TEXT,
    is_remote BOOLEAN,
    description TEXT,
    apply_url TEXT,
    source TEXT,
    posted_at TIMESTAMPTZ,
    ghost_job_flag BOOLEAN,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        j.id,
        j.external_id,
        j.title,
        j.company,
        j.location,
        j.is_remote,
        j.description,
        j.apply_url,
        j.source,
        j.posted_at,
        j.ghost_job_flag,
        1 - (j.job_embedding <=> query_embedding) AS similarity
    FROM jobs j
    WHERE j.job_embedding IS NOT NULL
      AND 1 - (j.job_embedding <=> query_embedding) > match_threshold
      AND j.ghost_job_flag = FALSE
    ORDER BY j.job_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
