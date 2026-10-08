// Vercel serverless function that stores one finished task in Supabase.
// The service role key stays on the server, so no database key is exposed in the browser.

const TABLE = 'ddt_responses';
const RATE_LIMIT_WINDOW_MIN = 10;
const RATE_LIMIT_MAX = 20;
const MAX_BODY_BYTES = 20000;

function getClientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (fwd) return String(fwd).split(',')[0].trim();
  return (req.socket && req.socket.remoteAddress) || 'unknown';
}

function sbHeaders(serviceKey, extra) {
  return {
    apikey: serviceKey,
    Authorization: 'Bearer ' + serviceKey,
    'Content-Type': 'application/json',
    ...extra,
  };
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method not allowed' });
    return;
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceKey) {
    res.status(500).json({ error: 'server not configured' });
    return;
  }
  const baseUrl = supabaseUrl.replace(/\/$/, '');

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) {
      res.status(400).json({ error: 'invalid json' });
      return;
    }
  }
  if (!body || typeof body !== 'object' || typeof body.participant_id !== 'string') {
    res.status(400).json({ error: 'invalid body' });
    return;
  }
  if (JSON.stringify(body).length > MAX_BODY_BYTES) {
    res.status(413).json({ error: 'payload too large' });
    return;
  }

  const row = {
    participant_id: body.participant_id,
    study_id: body.study_id || null,
    submitted_at: body.finished_at || new Date().toISOString(),
    payload: body,
  };

  const ip = getClientIp(req);

  try {
    const since = new Date(Date.now() - RATE_LIMIT_WINDOW_MIN * 60 * 1000).toISOString();
    const countUrl = baseUrl + '/rest/v1/rate_limit_log?select=id&ip=eq.' +
      encodeURIComponent(ip) + '&created_at=gte.' + encodeURIComponent(since);
    const countRes = await fetch(countUrl, {
      method: 'HEAD',
      headers: sbHeaders(serviceKey, { Prefer: 'count=exact' }),
    });
    const contentRange = countRes.headers.get('content-range') || '';
    const count = parseInt(contentRange.split('/')[1] || '0', 10);
    if (count >= RATE_LIMIT_MAX) {
      res.status(429).json({ error: 'too many requests, try again later' });
      return;
    }

    const insertRes = await fetch(baseUrl + '/rest/v1/' + TABLE, {
      method: 'POST',
      headers: sbHeaders(serviceKey, { Prefer: 'return=minimal' }),
      body: JSON.stringify(row),
    });
    if (!insertRes.ok) {
      res.status(insertRes.status).json({ error: 'insert failed' });
      return;
    }

    await fetch(baseUrl + '/rest/v1/rate_limit_log', {
      method: 'POST',
      headers: sbHeaders(serviceKey, { Prefer: 'return=minimal' }),
      body: JSON.stringify({ ip }),
    }).catch(() => {});

    res.status(200).json({ status: 'sent' });
  } catch (err) {
    res.status(500).json({ error: 'server error' });
  }
}
