const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

if (!fs.existsSync('uploads')) fs.mkdirSync('uploads');
if (!fs.existsSync('data.json')) fs.writeFileSync('data.json', '{"users":[],"notes":[]}');

const SECRET = 'devvault_secret_key';
let data = JSON.parse(fs.readFileSync('data.json'));

function saveData() {
  fs.writeFileSync('data.json', JSON.stringify(data, null, 2));
}

const auth = (req, res, next) => {
  const token = (req.headers.authorization || '').split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch (e) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

app.post('/register', (req, res) => {
  const { username, email, password, department } = req.body;
  if (data.users.find(u => u.email === email)) {
    return res.status(400).json({ error: 'Email already exists' });
  }
  bcrypt.hash(password, 10, (err, hash) => {
    const user = { id: Date.now(), username, email, password: hash, department };
    data.users.push(user);
    saveData();
    res.json({ success: true });
  });
});

app.post('/login', (req, res) => {
  const { email, password } = req.body;
  const user = data.users.find(u => u.email === email);
  if (!user) return res.status(400).json({ error: 'Invalid credentials' });
  bcrypt.compare(password, user.password, (err, match) => {
    if (!match) return res.status(400).json({ error: 'Invalid credentials' });
    const token = jwt.sign({ id: user.id, email: user.email }, SECRET);
    res.json({ token, user: { username: user.username, email: user.email } });
  });
});

app.get('/notes', auth, (req, res) => {
  res.json(data.notes.filter(n => n.user_id === req.user.id));
});

app.post('/notes', auth, (req, res) => {
  const { title, body, is_pinned, folder_id } = req.body;
  const note = {
    id: Date.now(),
    user_id: req.user.id,
    title,
    body,
    is_pinned: is_pinned ? 1 : 0,
    folder_id
  };
  data.notes.push(note);
  saveData();
  res.json({ id: note.id });
});

app.put('/notes/:id', auth, (req, res) => {
  const note = data.notes.find(n => n.id == req.params.id && n.user_id === req.user.id);
  if (note) {
    note.title = req.body.title;
    note.body = req.body.body;
    note.is_pinned = req.body.is_pinned ? 1 : 0;
    note.folder_id = req.body.folder_id;
    saveData();
  }
  res.json({ success: true });
});

app.delete('/notes/:id', auth, (req, res) => {
  data.notes = data.notes.filter(n => !(n.id == req.params.id && n.user_id === req.user.id));
  saveData();
  res.json({ success: true });
});

app.post('/share', auth, (req, res) => {
  res.json({ link: `/shared/${req.body.note_id}` });
});

const upload = multer({ dest: 'uploads/' });
app.post('/upload', auth, upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file' });
  const safe = req.file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
  const newName = Date.now() + '_' + safe;
  fs.renameSync(req.file.path, path.join('uploads', newName));
  res.json({ url: '/uploads/' + newName });
});

app.listen(5000, () => console.log('🚀 DevVault API running on port 5000'));