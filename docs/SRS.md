# DevVault - SRS (Software Requirements Specification)

## 1. Purpose
DevVault is an offline-first knowledge hub for students and staff.
It captures text, code, photos, voice, music and video; organizes them
into folders; shares with friends; and publishes resources to the
department. Works offline, syncs automatically when online.
One app, three rooms: Private, Friends, Department.

## 2. Users & Roles
- Student (individual): personal vault for notes and media.
- Staff (professor / HOD / class rep): post and moderate Department Hall.
- Guest: personal-only use without an account (offline only).

## 3. Functional Requirements
FR1  Notes: create/edit/delete with formatting (bold, italic, underline,
     lists) and code blocks with syntax highlighting.
FR2  Organization: folders, pinning, trash with restore (soft delete).
FR3  Search: instant search across notes, checklists and attachments.
FR4  Checklists: to-do lists inside notes.
FR5  Media capture: attach photos; record voice; speech-to-text conversion.
FR6  Playback: play music and video directly inside notes.
FR7  Offline-first: all core features work with zero internet;
     automatic cloud sync when connection returns.
FR8  Auth & onboarding: register/login (JWT); welcome slides;
     pick department at signup; guest mode for personal-only use.
FR9  Profile: username, department, avatar upload, app lock (PIN/biometric).
FR10 Themes: light / dark / system + accent colors.
FR11 Backup: export / import user data.
FR12 Share Link: generate secret read-only link for any note
     (send via WhatsApp/SMS; opens without login).
FR13 Shared Folders: invite friends by username or QR code;
     read/write permissions.
FR14 Department Hall: public board per department for announcements,
     past questions and resources; staff can post and moderate.
FR15 TV Cast: present notes/code on smart TVs and projectors.
FR16 AI Study Buddy: explain notes, generate quizzes, summarize lectures,
     help with code (online-only bonus feature).

## 4. Non-Functional Requirements
NFR1 Reliability: core features work 100% offline; no note lost on crash.
NFR2 Performance: search results under 1 second.
NFR3 Security: passwords hashed (bcrypt); JWT for private routes;
     data private by default; shared links read-only.
NFR4 Usability: create a note in max 2 taps; app teaches itself
     via onboarding slides.
NFR5 Scalability: schema supports many departments and thousands of users.
NFR6 Portability: one Flutter codebase for Android, Windows and Web.

## 5. Architecture
Frontend: Flutter + SQLite (local offline database)
Backend:  Node.js (Express) REST API + JWT
Database: MySQL + file storage for media
AI:       external API (online only)
