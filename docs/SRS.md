# Notepads - SRS

## Purpose
Mobile note app that works offline, syncs online, holds text + photos + voice + video.

## Users
Students, workers, anyone who writes things down. Role: User.

## Functional Requirements
- FR1: create/edit/delete notes (bold, italic, underline, lists)
- FR2: folders, pin, trash + restore (soft delete)
- FR3: instant search
- FR4: checklists inside notes
- FR5: attach photos; record voice; speech-to-text
- FR6: play music and video inside notes
- FR7: offline mode + cloud sync
- FR8: register/login (JWT); app lock (PIN/biometric)
- FR9: themes: light/dark/system + 3 accent colors
- FR10: backup & restore

## Non-Functional Requirements
- Core features work 100% offline
- Search under 1 second
- No note lost on crash
- Passwords hashed; JWT for private data
- Create a note in 2 taps