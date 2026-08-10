# Notepads - SDD

## Architecture
[Flutter app + SQLite] ⇄ REST API (Node + JWT) ⇄ PostgreSQL + file storage

## Database Tables
- users(id, email, password_hash, created_at)
- folders(id, user_id, name, color)
- notes(id, user_id, folder_id, title, body, is_pinned, deleted_at, updated_at)
- checklist_items(id, note_id, text, is_done, position)
- attachments(id, note_id, type, file_url, created_at)

## API Endpoints
- POST /register, POST /login → JWT
- GET/POST/PUT/DELETE /notes, /folders
- GET /sync?since=...
- POST /attachments

## Key Decisions
- Offline-first: save local first, sync later
- Soft delete for Trash
- Files in storage, not DB
- JWT for auth
- last-write-wins for sync conflicts
- MVVM in Flutter
- Theme = one saved setting