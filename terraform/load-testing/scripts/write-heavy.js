import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// ────────────────────────────────────────────────────────────────────────────
// Custom metrics — appear in Prometheus with the k6_ prefix when using
// the experimental-prometheus-rw output.
// ────────────────────────────────────────────────────────────────────────────
const usersCreated = new Counter('users_created_total');
const usersReadOk = new Counter('users_read_ok_total');
const usersReadMiss = new Counter('users_read_miss_total');
const usersListOk = new Counter('users_list_ok_total');
const writeErrors = new Rate('write_error_rate');
const readErrors = new Rate('read_error_rate');
const highestIdSeen = new Trend('highest_user_id_seen');

// ────────────────────────────────────────────────────────────────────────────
// Config — tweak via env vars on the TestRun manifest
// ────────────────────────────────────────────────────────────────────────────
const BASE_URL = __ENV.BASE_URL || 'https://users.internal.pe.onukwilip.xyz';
const DURATION = __ENV.DURATION || '2m';
const WRITE_RATE = parseInt(__ENV.WRITE_RATE || '10', 10);       // req/s per pod
const READ_RATE = parseInt(__ENV.READ_RATE || '5', 10);          // req/s per pod
const WRITE_VUS = parseInt(__ENV.WRITE_VUS || '20', 10);
const READ_VUS = parseInt(__ENV.READ_VUS || '10', 10);
const READ_GRACE_SECONDS = parseInt(__ENV.READ_GRACE_SECONDS || '30', 10);
const LIST_EVERY_N = parseInt(__ENV.LIST_EVERY_N || '20', 10);   // 1-in-N reads hits list endpoint

// Module-level state shared across VUs within the same pod.
// Writes to this are racy but we only care about approximate max, so
// occasional stale reads are fine — never corrupts.
let lastKnownMaxId = 0;

// ────────────────────────────────────────────────────────────────────────────
// Scenarios — writes start immediately, reads start after grace period
// ────────────────────────────────────────────────────────────────────────────
export const options = {
  scenarios: {
    write_users: {
      executor: 'constant-arrival-rate',
      exec: 'writeUser',
      rate: WRITE_RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: WRITE_VUS,
      maxVUs: WRITE_VUS * 2,
      tags: { scenario: 'write' },
    },
    read_users: {
      executor: 'constant-arrival-rate',
      exec: 'readUser',
      rate: READ_RATE,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: READ_VUS,
      maxVUs: READ_VUS * 2,
      startTime: `${READ_GRACE_SECONDS}s`,
      tags: { scenario: 'read' },
    },
  },
  thresholds: {
    'http_req_duration{scenario:write}':            ['p(95)<800',  'p(99)<2000'],
    'http_req_duration{scenario:read,kind:by_id}':  ['p(95)<300',  'p(99)<800'],
    'http_req_duration{scenario:read,kind:list}':   ['p(95)<1500', 'p(99)<3000'],
    'http_req_failed{scenario:write}':              ['rate<0.02'],
    'http_req_failed{scenario:read}':               ['rate<0.02'],
    'write_error_rate':                             ['rate<0.02'],
    'read_error_rate':                              ['rate<0.02'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  discardResponseBodies: false,
};

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

// Collision-free email across ALL pods and VUs.
// __ENV.K6_POD_INDEX is injected by the k6-operator runner; falls back
// to 'x' for local runs (they won't collide with pod runs).
function makeEmail(vu, iter) {
  const podIndex = __ENV.K6_POD_INDEX || 'x';
  return `loadtest-p${podIndex}-vu${vu}-i${iter}@example.com`;
}

function randomThinkTime() {
  // Most requests sleep 0.2–1.5s; occasional longer pauses (up to ~3s)
  return 0.2 + Math.random() * (Math.random() < 0.9 ? 1.3 : 2.8);
}

// Pick an ID to read. Bias toward recent IDs (mimics real-world "recently-
// created user fetches own profile") but include older IDs for cold cache.
function pickRandomId() {
  if (lastKnownMaxId < 1) return 1; // nothing created yet
  const recent = Math.random() < 0.7;
  if (recent) {
    // Last 20% of the ID range — hot path
    const floor = Math.max(1, Math.floor(lastKnownMaxId * 0.8));
    return floor + Math.floor(Math.random() * (lastKnownMaxId - floor + 1));
  }
  // Full range — exercises cold cache / full table span
  return 1 + Math.floor(Math.random() * lastKnownMaxId);
}

// ────────────────────────────────────────────────────────────────────────────
// WRITE scenario — POST /users
// ────────────────────────────────────────────────────────────────────────────
export function writeUser() {
  group('create_user', function () {
    const email = makeEmail(__VU, __ITER);
    const payload = JSON.stringify({
      name: `LoadTest User ${__VU}-${__ITER}`,
      email: email,
      mobile: `2348${String(__VU).padStart(4, '0')}${String(__ITER).padStart(4, '0')}`,
    });

    const params = {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'POST /users' },
    };

    const res = http.post(`${BASE_URL}/users`, payload, params);

    const ok = check(res, {
      'write: status is 201': (r) => r.status === 201,
      'write: response has id': (r) => {
        try {
          const body = r.json();
          return body && (body.id !== undefined || body.ID !== undefined);
        } catch (_) {
          return false;
        }
      },
    });

    if (ok) {
      usersCreated.add(1);
      writeErrors.add(false);
      // Capture the ID so readers have a realistic ceiling.
      try {
        const body = res.json();
        const id = body.id ?? body.ID;
        if (typeof id === 'number' && id > lastKnownMaxId) {
          lastKnownMaxId = id;
          highestIdSeen.add(id);
        }
      } catch (_) { /* ignore */ }
    } else {
      writeErrors.add(true);
      if (__ITER % 50 === 0) {
        console.warn(`[write] status=${res.status} body=${res.body ? res.body.substring(0, 200) : ''}`);
      }
    }
  });

  sleep(randomThinkTime());
}

// ────────────────────────────────────────────────────────────────────────────
// READ scenario — mostly GET /users/{id}, occasionally GET /users (list all)
// ────────────────────────────────────────────────────────────────────────────
export function readUser() {
  // 1-in-N reads hits the list endpoint to exercise the full-scan path.
  if (LIST_EVERY_N > 0 && __ITER % LIST_EVERY_N === 0) {
    listUsers();
  } else {
    getUserById();
  }
  sleep(randomThinkTime());
}

function getUserById() {
  group('read_user_by_id', function () {
    const id = pickRandomId();

    const params = {
      tags: {
        endpoint: 'GET /users/{id}',
        kind: 'by_id',
      },
    };

    const res = http.get(`${BASE_URL}/users/${id}`, params);

    check(res, {
      'read: status is 200 or 404': (r) => r.status === 200 || r.status === 404,
      'read: not 5xx': (r) => r.status < 500,
    });

    if (res.status === 200) {
      usersReadOk.add(1);
      readErrors.add(false);
    } else if (res.status === 404) {
      // 404 is expected when a reader in pod A queries an ID that a writer
      // in pod B hasn't fully committed yet, or an old ID that was never
      // created. We don't count this as an error.
      usersReadMiss.add(1);
      readErrors.add(false);
    } else {
      readErrors.add(true);
      if (__ITER % 50 === 0) {
        console.warn(`[read] id=${id} status=${res.status}`);
      }
    }
  });
}

function listUsers() {
  group('list_users', function () {
    const params = {
      tags: {
        endpoint: 'GET /users',
        kind: 'list',
      },
    };

    const res = http.get(`${BASE_URL}/users`, params);

    const ok = check(res, {
      'list: status is 200': (r) => r.status === 200,
      'list: response is array': (r) => {
        try {
          const body = r.json();
          return Array.isArray(body) || Array.isArray(body.users) || Array.isArray(body.data);
        } catch (_) {
          return false;
        }
      },
    });

    if (ok) {
      usersListOk.add(1);
      readErrors.add(false);
    } else {
      readErrors.add(true);
      if (__ITER % 20 === 0) {
        console.warn(`[list] status=${res.status}`);
      }
    }
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Summary hook
// ────────────────────────────────────────────────────────────────────────────
export function handleSummary(data) {
  const writes = data.metrics.users_created_total?.values.count || 0;
  const readOk = data.metrics.users_read_ok_total?.values.count || 0;
  const readMiss = data.metrics.users_read_miss_total?.values.count || 0;
  const listOk = data.metrics.users_list_ok_total?.values.count || 0;
  const highestId = data.metrics.highest_user_id_seen?.values.max || 0;

  const p95Write = data.metrics['http_req_duration{scenario:write}']?.values['p(95)'] || 0;
  const p95ReadById = data.metrics['http_req_duration{scenario:read,kind:by_id}']?.values['p(95)'] || 0;
  const p95List = data.metrics['http_req_duration{scenario:read,kind:list}']?.values['p(95)'] || 0;

  const summary = `
╔═══════════════════════════════════════════════════╗
║           Users Microservice Load Test            ║
╠═══════════════════════════════════════════════════╣
║ Users created:           ${String(writes).padStart(10)}               ║
║ Reads by ID (200):       ${String(readOk).padStart(10)}               ║
║ Reads by ID (404):       ${String(readMiss).padStart(10)}               ║
║ List requests (200):     ${String(listOk).padStart(10)}               ║
║ Highest ID observed:     ${String(highestId).padStart(10)}               ║
╠═══════════════════════════════════════════════════╣
║ p95 write latency:       ${String(p95Write.toFixed(0)).padStart(7)} ms            ║
║ p95 read-by-id latency:  ${String(p95ReadById.toFixed(0)).padStart(7)} ms            ║
║ p95 list-all latency:    ${String(p95List.toFixed(0)).padStart(7)} ms            ║
╚═══════════════════════════════════════════════════╝
`;
  return {
    stdout: summary,
    '/tmp/summary.json': JSON.stringify(data, null, 2),
  };
}
