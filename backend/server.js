require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');

const app = express();
app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'devvault',
});
const JWT_SECRET = process.env.JWT_SECRET || 'change-me';

function auth(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Login required' });
  }
}

// ---------- AUTH ----------
app.post('/register', async (req, res) => {
  const { username, email, password, department } = req.body;
  const hash = await bcrypt.hash(password, 10);
  const [r] = await pool.query(
    'INSERT INTO users (username, email, password_hash, department) VALUES (?,?,?,?)',
    [username || email.split('@')[0], email, hash, department || 'CSC']
  );
  res.json({ ok: true, userId: r.insertId });
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const [rows] = await pool.query('SELECT * FROM users WHERE email=?', [email]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash)))
    return res.status(401).json({ error: 'Wrong email or password' });
  const token = jwt.sign(
    { id: user.id, username: user.username, department: user.department, role: user.role },
    JWT_SECRET, { expiresIn: '7d' }
  );
  res.json({
    token,
    user: { id: user.id, username: user.username, email: user.email,
            department: user.department, role: user.role, avatar_url: user.avatar_url }
  });
});

// ---------- FOLDERS ----------
app.get('/folders', auth, async (req, res) => {
  const [mine] = await pool.query("SELECT *, 'owner' AS access FROM folders WHERE user_id=?", [req.user.id]);
  const [shared] = await pool.query(
    'SELECT f.*, fm.permission AS access FROM folder_members fm JOIN folders f ON f.id=fm.folder_id WHERE fm.user_id=?',
    [req.user.id]
  );
  res.json([...mine, ...shared]);
});

app.post('/folders', auth, async (req, res) => {
  const { name, color } = req.body;
  const [r] = await pool.query('INSERT INTO folders (user_id, name, color) VALUES (?,?,?)',
    [req.user.id, name, color || '#F5C542']);
  res.json({ id: r.insertId });
});

app.put('/folders/:id/public', auth, async (req, res) => {
  await pool.query('UPDATE folders SET is_public=1 WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
  res.json({ ok: true });
});

app.post('/folders/:id/invite', auth, async (req, res) => {
  const { username } = req.body;
  const [u] = await pool.query('SELECT id FROM users WHERE username=?', [username]);
  if (!u[0]) return res.status(404).json({ error: 'User not found' });
  await pool.query('INSERT IGNORE INTO folder_members (folder_id, user_id) VALUES (?,?)',
    [req.params.id, u[0].id]);
  res.json({ ok: true });
});

// ---------- NOTES ----------
app.get('/notes', auth, async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM notes WHERE user_id=? AND deleted_at IS NULL ORDER BY is_pinned DESC, updated_at DESC',
    [req.user.id]
  );
  res.json(rows);
});

app.get('/folders/:id/notes', auth, async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM notes WHERE folder_id=? AND deleted_at IS NULL ORDER BY updated_at DESC',
    [req.params.id]
  );
  res.json(rows);
});

app.post('/notes', auth, async (req, res) => {
  const { title, body, folder_id } = req.body;
  const [r] = await pool.query(
    'INSERT INTO notes (user_id, title, body, folder_id) VALUES (?,?,?,?)',
    [req.user.id, title, body || '', folder_id || null]
  );
  const [rows] = await pool.query('SELECT * FROM notes WHERE id=?', [r.insertId]);
  res.json(rows[0]);
});

app.put('/notes/:id', auth, async (req, res) => {
  const { title, body, is_pinned, folder_id } = req.body;
  await pool.query(
    'UPDATE notes SET title=?, body=?, is_pinned=?, folder_id=? WHERE id=? AND user_id=?',
    [title, body, is_pinned ? 1 : 0, folder_id, req.params.id, req.user.id]
  );
  const [rows] = await pool.query('SELECT * FROM notes WHERE id=?', [req.params.id]);
  res.json(rows[0]);
});

app.delete('/notes/:id', auth, async (req, res) => {
  await pool.query('UPDATE notes SET deleted_at=NOW() WHERE id=? AND user_id=?',
    [req.params.id, req.user.id]);
  res.json({ ok: true });
});

// ---------- SHARE LINK ----------
app.post('/share', auth, async (req, res) => {
  const { note_id } = req.body;
  const code = Math.random().toString(36).slice(2, 8);
  await pool.query('INSERT INTO shared_links (code, note_id, created_by) VALUES (?,?,?)',
    [code, note_id, req.user.id]);
  res.json({ code, link: '/s/' + code });
});

app.get('/s/:code', async (req, res) => {
  const [rows] = await pool.query(
    'SELECT n.title, n.body, n.updated_at, u.username FROM shared_links l ' +
    'JOIN notes n ON n.id=l.note_id JOIN users u ON u.id=l.created_by WHERE l.code=?',
    [req.params.code]
  );
  if (!rows[0]) return res.status(404).json({ error: 'Link not found' });
  res.json(rows[0]);
});

// ---------- DEPARTMENT HALL ----------
app.get('/public/folders', auth, async (req, res) => {
  const [rows] = await pool.query(
    'SELECT f.*, u.username AS owner FROM folders f JOIN users u ON u.id=f.user_id ' +
    'WHERE f.is_public=1 AND u.department=? ORDER BY f.created_at DESC',
    [req.user.department]
  );
  res.json(rows);
});

// ---------- SYNC ----------
app.get('/sync', auth, async (req, res) => {
  const since = req.query.since || '1970-01-01';
  const [rows] = await pool.query(
    'SELECT * FROM notes WHERE user_id=? AND updated_at > ? ORDER BY updated_at',
    [req.user.id, since]
  );
  res.json(rows);
});

// ---------- AI STUDY BUDDY (stub) ----------
app.post('/ask', auth, async (req, res) => {
  // TODO: connect Gemini/OpenAI in the next milestone
  res.json({ answer: 'AI Study Buddy arrives in the next milestone.' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`DevVault API running on port ${PORT}`));