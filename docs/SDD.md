  DEVVAULT SOFTWARE DESIGN DOCUMENT(SDD)
  
This explains the "How" and the technical architecture
1. System Architecture:
DevVault uses a Client-Server architecture with an Offline-First approach.
Frontend: Flutter framework (compiles to Android, Windows, and Web). Uses local SQLite for instant offline access.
Backend: Node.js with Express.js (REST API).
Database: MySQL (Relational database for structured data like users, notes, and folders).
Authentication: JSON Web Tokens (JWT) for stateless, secure API access. Passwords are hashed using bcrypt.

2. Database Schema (Key Tables):
users: Stores credentials, department, and role (student/staff).
folders: Organizes notes. Includes an is_public flag for Department Halls.
folder_members: Manages permissions for Shared Folders.
notes: Stores title, markdown body, and timestamps for sync.
attachments: Links media files (audio, video, images) to specific notes.
shared_links: Stores secret, read-only access codes for public sharing.

3. Key API Endpoints:
POST /register & POST /login: Handles secure authentication.
GET /notes & POST /notes: CRUD operations for user data.
POST /share: Generates a unique 6-character secret code for a note.
GET /s/:code: Public endpoint to fetch a shared note without authentication.
GET /public/folders: Retrieves department-wide public resources.
4. Security & Privacy:
Data is private by default.
API routes are protected by middleware that verifies the JWT Bearer token.
Shared links are strictly read-only to prevent unauthorized modifications.

## Architecture
[Flutter app + SQLite] ⇄ REST API (Node + JWT) ⇄ PostgreSQL + file storage

<img width="1664" height="928" alt="1786549193" src="https://github.com/user-attachments/assets/42e269f4-736d-4fcd-8fc8-a419727a6118" />

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
<img width="1664" height="928" alt="1786545707" src="https://github.com/user-attachments/assets/c73d6a46-8f9d-4b04-ae50-b0fd75060f73" />

**System Flow**
<img width="1664" height="928" alt="1786545874" src="https://github.com/user-attachments/assets/aaa75ac9-9c8f-4e1c-a56b-a19d795c3e80" />

## Key Decisions
- Offline-first: save local first, sync later
- Soft delete for Trash
- Files in storage, not DB
- JWT for auth
- last-write-wins for sync conflicts
- MVVM in Flutter
- Theme = one saved setting
- <img width="1664" height="928" alt="1786510113" src="https://github.com/user-attachments/assets/515d1a68-7439-4ab2-8fa1-6822a9b92072" />
