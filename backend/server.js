const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1E9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } }); // 50MB max

// Serve uploaded files statically
app.use('/uploads', express.static(uploadsDir));

// MySQL connection
const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'devvault'
});

db.connect(err => {
  if (err) throw err;
  console.log('✅ Connected to MySQL');
});

// JWT middleware
const authenticate = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  
  jwt.verify(token, process.env.JWT_SECRET || 'devvault_secret_key', (err, decoded) => {
    if (err) return res.status(401).json({ error: 'Invalid token' });
    req.userId = decoded.userId;
    next();
  });
};

// ---- AUTH ROUTES ----
app.post('/register', async (req, res) => {
  const { username, email, password, department } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  
  db.query(
    'INSERT INTO users (username, email, password_hash, department) VALUES (?, ?, ?, ?)',
    [username, email, hashedPassword, department],
    (err, result) => {
      if (err) return res.status(400).json({ error: 'Email already exists' });
      res.json({ message: 'User registered successfully' });
    }
  );
});

app.post('/login', (req, res) => {
  const { email, password } = req.body;
  
  db.query('SELECT * FROM users WHERE email = ?', [email], async (err, results) => {
    if (err || results.length === 0) return res.status(401).json({ error: 'Invalid credentials' });
    
    const user = results[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!validPassword) return res.status(401).json({ error: 'Invalid credentials' });
    
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET || 'devvault_secret_key', { expiresIn: '7d' });
    res.json({ token, user: { id: user.id, username: user.username, email: user.email, department: user.department } });
  });
});

// ---- NOTES ROUTES ----
app.get('/notes', authenticate, (req, res) => {
  db.query('SELECT * FROM notes WHERE user_id = ? ORDER BY updated_at DESC', [req.userId], (err, results) => {
    if (err) return res.status(500).json({ error: 'Failed to fetch notes' });
    res.json(results);
  });
});

app.post('/notes', authenticate, (req, res) => {
  const { title, body, is_pinned, folder_id } = req.body;
  
  db.query(
    'INSERT INTO notes (user_id, title, body, is_pinned, folder_id) VALUES (?, ?, ?, ?, ?)',
    [req.userId, title, body, is_pinned ? 1 : 0, folder_id],
    (err, result) => {
      if (err) return res.status(500).json({ error: 'Failed to create note' });
      res.json({ id: result.insertId, message: 'Note created' });
    }
  );
});

app.put('/notes/:id', authenticate, (req, res) => {
  const { title, body, is_pinned, folder_id } = req.body;
  
  db.query(
    'UPDATE notes SET title = ?, body = ?, is_pinned = ?, folder_id = ? WHERE id = ? AND user_id = ?',
    [title, body, is_pinned ? 1 : 0, folder_id, req.params.id, req.userId],
    (err, result) => {
      if (err) return res.status(500).json({ error: 'Failed to update note' });
      res.json({ message: 'Note updated' });
    }
  );
});

app.delete('/notes/:id', authenticate, (req, res) => {
  db.query('DELETE FROM notes WHERE id = ? AND user_id = ?', [req.params.id, req.userId], (err, result) => {
    if (err) return res.status(500).json({ error: 'Failed to delete note' });
    res.json({ message: 'Note deleted' });
  });
});

// ---- SHARE ROUTES ----
app.post('/share', authenticate, (req, res) => {
  const { note_id } = req.body;
  const code = Math.random().toString(36).substring(2, 8);
  
  db.query(
    'INSERT INTO shares (note_id, code) VALUES (?, ?)',
    [note_id, code],
    (err, result) => {
      if (err) return res.status(500).json({ error: 'Failed to create share link' });
      res.json({ code, link: `/s/${code}` });
    }
  );
});

app.get('/s/:code', (req, res) => {
  db.query(
    'SELECT n.title, n.body, n.updated_at, u.username FROM shares s JOIN notes n ON s.note_id = n.id JOIN users u ON n.user_id = u.id WHERE s.code = ?',
    [req.params.code],
    (err, results) => {
      if (err || results.length === 0) return res.status(404).json({ error: 'Link not found' });
      res.json(results[0]);
    }
  );
});

// ---- MEDIA UPLOAD ----
app.post('/upload', authenticate, upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  res.json({ 
    url: `/uploads/${req.file.filename}`,
    originalName: req.file.originalname,
    size: req.file.size
  });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 DevVault API running on port ${PORT}`);
});