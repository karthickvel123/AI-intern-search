import httpx

BASE_URL = 'http://127.0.0.1:8000'
client = httpx.Client(base_url=BASE_URL, timeout=45)

print('=== End-to-End Backend Verification ===')

# 1. Health check
res_health = client.get('/health')
assert res_health.status_code == 200
print('1. GET /health ->', res_health.json())

# 2. Sync Jobs
res_sync = client.post('/api/v1/jobs/sync')
assert res_sync.status_code == 200
sync_data = res_sync.json()
print(f"2. POST /api/v1/jobs/sync -> Fetched: {sync_data['total_fetched']}, Synced: {sync_data['total_synced']}, Ghost jobs: {sync_data['ghost_jobs_count']}")

# 3. Matches
res_matches = client.get('/api/v1/jobs/matches', params={'profile_id': 'test-profile-e2e', 'limit': 5})
assert res_matches.status_code == 200
matches_data = res_matches.json()
print(f"3. GET /api/v1/jobs/matches -> Total matches: {matches_data['total_matches']}")
first_job = matches_data['matches'][0]
score = first_job['match_score']
print(f"   Top Match: {first_job['company']} - {first_job['title']} ({score}%)")
print(f"   Reason: {first_job['match_reason']}")
print(f"   Ghost Job Flag: {first_job['ghost_job_flag']}")
assert 'match_score' in first_job
assert 'matched_skills' in first_job
assert 'missing_skills' in first_job
assert 'posted_hours_ago' in first_job

# 4. Tailor Resume for Top Match
job_id = first_job['id'] or first_job['external_id']
res_tailor = client.post(f'/api/v1/jobs/{job_id}/tailor', json={'profile_id': 'test-profile-e2e'})
assert res_tailor.status_code == 200
tailor_data = res_tailor.json()
print('4. POST /api/v1/jobs/{job_id}/tailor ->')
print(f"   Bullet Diffs generated: {len(tailor_data['bullet_diffs'])}")
print(f"   Sample tailored bullet: {tailor_data['bullet_diffs'][0]['tailored_bullet']}")
print(f"   Referral DM: {tailor_data['referral_dm']}")
assert len(tailor_data['bullet_diffs']) > 0
assert 'referral_dm' in tailor_data

# 5. Tracker Save & Update
res_tracker_patch = client.patch(
    f'/api/v1/tracker/{job_id}',
    json={'profile_id': 'test-profile-e2e', 'status': 'interview', 'notes': 'Technical screen scheduled'}
)
assert res_tracker_patch.status_code == 200
print(f"5. PATCH /api/v1/tracker/{job_id} -> Saved status: {res_tracker_patch.json()['status']}")

# 6. Tracker List
res_tracker_get = client.get('/api/v1/tracker', params={'profile_id': 'test-profile-e2e'})
assert res_tracker_get.status_code == 200
tracker_data = res_tracker_get.json()
print(f"6. GET /api/v1/tracker -> Total tracked: {tracker_data['total']}")
assert tracker_data['total'] >= 1
assert tracker_data['applications'][0]['job_id'] == job_id
assert tracker_data['applications'][0]['status'] == 'interview'

print('\n✓ ALL ENDPOINTS & SERIALIZATION CONTRACTS VERIFIED 100% END-TO-END!')
