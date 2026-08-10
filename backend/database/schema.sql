-- Notepads database schema

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE folders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  color VARCHAR(20) DEFAULT '#F5C542',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notes (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  folder_id INT REFERENCES folders(id) ON DELETE SET NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT DEFAULT '',
  is_pinned BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE checklist_items (
  id SERIAL PRIMARY KEY,
  note_id INT REFERENCES notes(id) ON DELETE CASCADE,
  text VARCHAR(500) NOT NULL,
  is_done BOOLEAN DEFAULT FALSE,
  position INT DEFAULT 0
);

CREATE TABLE attachments (
  id SERIAL PRIMARY KEY,
  note_id INT REFERENCES notes(id) ON DELETE CASCADE,
  type VARCHAR(20) NOT NULL,
  file_url TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notes_user_updated ON notes(user_id, updated_at);