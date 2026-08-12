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
  database: process.env.DB_NAME || 'notepads',
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

// ---- AUTH ----
app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  const hash = await bcrypt.hash(password, 10);
  const [r] = await pool.query('INSERT INTO users (email, password_hash) VALUES (?,?)', [email, hash]);
  res.json({ ok: true, userId: r.insertId });
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const [rows] = await pool.query('SELECT * FROM users WHERE email=?', [email]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash)))
    return res.status(401).json({ error: 'Wrong email or password' });
  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ token });
});

// ---- NOTES ----
app.get('/notes', auth, async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM notes WHERE user_id=? AND deleted_at IS NULL ORDER BY updated_at DESC',
    [req.user.id]
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
  const { title, body, is_pinned } = req.body;
  await pool.query(
    'UPDATE notes SET title=?, body=?, is_pinned=? WHERE id=? AND user_id=?',
    [title, body, is_pinned ? 1 : 0, req.params.id, req.user.id]
  );
  const [rows] = await pool.query('SELECT * FROM notes WHERE id=?', [req.params.id]);
  res.json(rows[0]);
});

app.delete('/notes/:id', auth, async (req, res) => {
  await pool.query('UPDATE notes SET deleted_at=NOW() WHERE id=? AND user_id=?', [req.params.id, req.user.id]);
  res.json({ ok: true });
});

// ---- SYNC ----
app.get('/sync', auth, async (req, res) => {
  const since = req.query.since || '1970-01-01';
  const [rows] = await pool.query(
    'SELECT * FROM notes WHERE user_id=? AND updated_at > ? ORDER BY updated_at',
    [req.user.id, since]
  );
  res.json(rows);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Notepads API running on port ${PORT}`));