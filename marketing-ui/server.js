const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const DOCS_PATH = process.env.MARKETING_DOCS_PATH
  ? path.resolve(process.env.MARKETING_DOCS_PATH)
  : path.resolve(__dirname, '../marketing');

const LOG_FILE = path.join(DOCS_PATH, 'outreach-log.md');

const CHANNELS = [
  { id: 'reddit-aviation', label: 'r/aviation', type: 'Reddit post' },
  { id: 'reddit-flying', label: 'r/flying', type: 'Reddit post' },
  { id: 'reddit-planespotting', label: 'r/PlaneSpotting', type: 'Reddit post' },
  { id: 'reddit-atc', label: 'r/ATC', type: 'Reddit post' },
  { id: 'reddit-flightsim', label: 'r/flightsim', type: 'Reddit post' },
  { id: 'reddit-rtlsdr', label: 'r/RTLSDR', type: 'Reddit post' },
  { id: 'pprune', label: 'PPRuNe forums', type: 'Forum post' },
  { id: 'flyerforums', label: 'FlyerForums', type: 'Forum post' },
  { id: 'youtube-creator-dm', label: 'YouTube creator outreach DM', type: 'Creator DM' },
  { id: 'tiktok-creator-dm', label: 'TikTok/Instagram creator outreach DM', type: 'Creator DM' },
  { id: 'aso-short-description', label: 'Play Store short description (ASO)', type: 'ASO copy' },
  { id: 'aso-long-description', label: 'Play Store long description (ASO)', type: 'ASO copy' },
];

// Derive a channel descriptor for dynamically-discovered channels (e.g. scout-found subreddits)
function resolveChannel(channelId) {
  const known = CHANNELS.find(c => c.id === channelId);
  if (known) return known;
  // Infer label/type from id pattern: reddit-<name> → r/<name>
  if (channelId.startsWith('reddit-')) {
    const sub = channelId.slice(7);
    return { id: channelId, label: `r/${sub}`, type: 'Reddit post' };
  }
  return { id: channelId, label: channelId, type: 'Post' };
}

function readDrafts() {
  if (!fs.existsSync(DOCS_PATH)) fs.mkdirSync(DOCS_PATH, { recursive: true });
  return fs.readdirSync(DOCS_PATH)
    .filter(f => f.endsWith('.md') && f !== 'outreach-log.md')
    .map(filename => {
      const content = fs.readFileSync(path.join(DOCS_PATH, filename), 'utf8');
      const frontmatter = {};
      const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
      if (fmMatch) {
        fmMatch[1].split('\n').forEach(line => {
          const [key, ...val] = line.split(': ');
          if (key && val.length) frontmatter[key.trim()] = val.join(': ').trim();
        });
      }
      return { filename, content, ...frontmatter };
    })
    .sort((a, b) => (b.date || '').localeCompare(a.date || ''));
}

function appendToLog(entry) {
  const row = `| ${entry.date} | ${entry.channel} | ${entry.type} | ${entry.filename} | ${entry.status} | ${entry.notes || ''} |`;
  if (!fs.existsSync(LOG_FILE)) {
    fs.writeFileSync(LOG_FILE, '# Outreach Log\n\n| Date | Channel | Type | File | Status | Notes |\n|------|---------|------|------|--------|-------|\n' + row + '\n');
  } else {
    fs.appendFileSync(LOG_FILE, row + '\n');
  }
}

function updateLogStatus(filename, newStatus) {
  if (!fs.existsSync(LOG_FILE)) return;
  let log = fs.readFileSync(LOG_FILE, 'utf8');
  const escaped = filename.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  log = log.replace(
    new RegExp(`(\\| [^|]+ \\| [^|]+ \\| [^|]+ \\| ${escaped} \\| )([^|]+)(\\|)`),
    `$1${newStatus} $3`
  );
  fs.writeFileSync(LOG_FILE, log);
}

// --- API ---

app.get('/api/channels', (req, res) => res.json(CHANNELS));

app.get('/api/drafts', (req, res) => {
  try { res.json(readDrafts()); }
  catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/drafts/:filename', (req, res) => {
  const file = path.join(DOCS_PATH, path.basename(req.params.filename));
  if (!fs.existsSync(file)) return res.status(404).json({ error: 'Not found' });
  res.json({ content: fs.readFileSync(file, 'utf8') });
});

app.post('/api/drafts/:filename/mark-posted', (req, res) => {
  const filename = path.basename(req.params.filename);
  const file = path.join(DOCS_PATH, filename);
  if (!fs.existsSync(file)) return res.status(404).json({ error: 'Not found' });
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(/^status: .*/m, 'status: Posted');
  fs.writeFileSync(file, content);
  updateLogStatus(filename, 'Posted');
  res.json({ ok: true });
});

app.delete('/api/drafts/:filename', (req, res) => {
  const file = path.join(DOCS_PATH, path.basename(req.params.filename));
  if (!fs.existsSync(file)) return res.status(404).json({ error: 'Not found' });
  fs.unlinkSync(file);
  res.json({ ok: true });
});

// Save a draft that was generated externally and pasted in
app.post('/api/drafts', (req, res) => {
  const { channelId, content } = req.body;
  if (!channelId || !content) return res.status(400).json({ error: 'channelId and content required' });
  const channel = resolveChannel(channelId);
  const datestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filename = `${channelId}-${datestamp}-draft.md`;
  fs.writeFileSync(path.join(DOCS_PATH, filename), content);
  appendToLog({
    date: new Date().toISOString().split('T')[0],
    channel: channel.label,
    type: channel.type,
    filename,
    status: 'Drafted',
    notes: 'Saved via API',
  });
  res.json({ filename });
});

app.get('/api/log', (req, res) => {
  if (!fs.existsSync(LOG_FILE)) return res.json({ content: '# Outreach Log\n\nNo entries yet.' });
  res.json({ content: fs.readFileSync(LOG_FILE, 'utf8') });
});


const PORT = process.env.PORT || 3000;
const BIND = process.env.BIND_HOST || '127.0.0.1';
app.listen(PORT, BIND, () => {
  console.log(`Marketing UI running on ${BIND}:${PORT}`);
  console.log(`Content path: ${DOCS_PATH}`);
});
