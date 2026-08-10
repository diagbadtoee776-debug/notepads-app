require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const JWT_SECRET = process.env.JWT_SECRET || 'change-me';

// Middleware: check JWT on private routes
function auth(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Login required' });
  }
}

// ---- AUTH ----
app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  const hash = await bcrypt.hash(password, 10);
  const r = await pool.query(
    'INSERT INTO users (email, password_hash) VALUES ($1,$2) RETURNING id',
    [email, hash]
  );
  res.json({ ok: true, userId: r.rows[0].id });
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const r = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
  const user = r.rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash)))
    return res.status(401).json({ error: 'Wrong email or password' });
  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ token });
});

// ---- NOTES ----
app.get('/notes', auth, async (req, res) => {
  const r = await pool.query(
    'SELECT * FROM notes WHERE user_id=$1 AND deleted_at IS NULL ORDER BY updated_at DESC',
    [req.user.id]
  );
  res.json(r.rows);
});

app.post('/notes', auth, async (req, res) => {
  const { title, body, folder_id } = req.body;
  const r = await pool.query(
    'INSERT INTO notes (user_id, title, body, folder_id) VALUES ($1,$2,$3,$4) RETURNING *',
    [req.user.id, title, body || '', folder_id || null]
  );
  res.json(r.rows[0]);
});

app.put('/notes/:id', auth, async (req, res) => {
  const { title, body, is_pinned } = req.body;
  const r = await pool.query(
    'UPDATE notes SET title=$1, body=$2, is_pinned=$3, updated_at=NOW() WHERE id=$4 AND user_id=$5 RETURNING *',
    [title, body, is_pinned, req.params.id, req.user.id]
  );
  res.json(r.rows[0]);
});

app.delete('/notes/:id', auth, async (req, res) => {
  await pool.query(
    'UPDATE notes SET deleted_at=NOW() WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id]
  );
  res.json({ ok: true });
});

// ---- SYNC ----
app.get('/sync', auth, async (req, res) => {
  const since = req.query.since || '1970-01-01';
  const r = await pool.query(
    'SELECT * FROM notes WHERE user_id=$1 AND updated_at > $2 ORDER BY updated_at',
    [req.user.id, since]
  );
  res.json(r.rows);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Notepads API running on port ${PORT}`));