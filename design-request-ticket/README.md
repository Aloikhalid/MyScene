# Design Request Ticket

A bilingual (English / Arabic) 5-step ticket form for the ISPOR / PEOR design
team, implementing the `Design Request Ticket.dc.html` design from
claude.ai/design. Plain HTML/CSS/JS — no build step, no framework.

Steps: Requester Info → Request Basics → Dimensions & Specs → Deadlines →
Content & Assets, with per-step validation, multi-select chips, file
uploads, and a success screen showing the generated ticket ID.

## Files

- `index.html` / `styles.css` / `app.js` — the form itself
- `config.js` — set `SCRIPT_URL` here
- `apps-script/Code.gs` — Google Apps Script backend that appends each
  submission to a "Tickets" sheet and saves uploaded files to Drive
- `fonts/` — brand fonts (Libre Baskerville, Montserrat Arabic, Roboto
  Condensed) pulled from the ISPOR Design system

## Setup

1. Create a Google Sheet with a tab named `Tickets`.
2. Open **Extensions → Apps Script**, paste in `apps-script/Code.gs`.
3. Update `DRIVE_FOLDER_ID` in `Code.gs` to a Drive folder you own (or leave
   the existing ID if you have access to it).
4. **Deploy → New deployment → Web app** — Execute as **Me**, Access
   **Anyone** — then copy the `/exec` URL.
5. Paste that URL into `SCRIPT_URL` in `config.js`.
6. Serve the folder as a static site (GitHub Pages, Apps Script HTML
   service, Netlify, or just open `index.html` locally) and submit a test
   ticket to confirm a row lands in the sheet.

## Notes

- The frontend intentionally sends the POST body with
  `Content-Type: text/plain` — using `application/json` would trigger a
  CORS preflight (`OPTIONS`) request, which Apps Script web apps don't
  handle.
- Uploaded files are read client-side with `FileReader` and sent as
  base64; very large attachments will make for a large request body since
  everything goes through a single `doPost` call.
