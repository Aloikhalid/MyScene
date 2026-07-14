// ISPOR / PEOR Design Ticket — Google Apps Script backend
// Paste this in your Google Sheet: Extensions → Apps Script
// Then: Deploy → New deployment → Web app → Execute as: Me → Access: Anyone
// Copy the web app URL — that goes into ../config.js as SCRIPT_URL.

const SHEET_NAME = 'Tickets';
const DRIVE_FOLDER_ID = '1-_awjQ7Ax2vYCrMoOHcKjxxLFTi2hu12'; // ISPOR Design Tickets folder

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const data = JSON.parse(e.postData.contents);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];

    // Ticket ID: ISPOR-2026-001, ISPOR-2026-002, ...
    const year = new Date().getFullYear();
    const num = sheet.getLastRow(); // row 1 is the header, so this counts tickets + 1... adjust below
    const ticketNumber = Math.max(num, 1); // first ticket lands as 001
    const ticketId = 'ISPOR-' + year + '-' + String(ticketNumber).padStart(3, '0');

    // Save uploaded files (sent as base64) into a Drive subfolder named after the ticket
    let fileLinks = [];
    if (data.files && data.files.length) {
      const folder = DriveApp.getFolderById(DRIVE_FOLDER_ID);
      const sub = folder.createFolder(ticketId + ' — ' + (data.title || 'untitled'));
      data.files.forEach(function (f) {
        const blob = Utilities.newBlob(
          Utilities.base64Decode(f.data),
          f.mimeType || 'application/octet-stream',
          f.name || 'file'
        );
        const file = sub.createFile(blob);
        fileLinks.push(file.getUrl());
      });
    }

    sheet.appendRow([
      ticketId,                       // A  Ticket ID
      new Date(),                     // B  Submitted at
      data.fullName || '',            // C  Full name
      data.team || '',                // D  Team
      data.contact || '',             // E  Contact
      data.title || '',               // F  Request title
      data.designType || '',          // G  Design type
      data.otherDesignType || '',     // H  Other design type (if "Other")
      data.language || '',            // I  Language (Arabic / English / Both)
      data.brief || '',               // J  Brief
      data.priority || '',            // K  Priority
      data.size || '',                // L  Size
      data.formats || '',             // M  File formats (PNG / PDF / PPTX)
      data.firstDraftDate || '',      // N  First draft needed by
      data.finalDate || '',           // O  Final file needed by
      data.publishDate || '',         // P  Publish / event date
      data.copyText || '',            // Q  Text / copy
      fileLinks.join('\n'),           // R  Uploaded file links (Drive)
      data.referenceLinks || '',      // S  Reference links
      data.styleNotes || '',          // T  Colour / style notes
      data.avoid || '',               // U  Things to avoid
      'New',                          // V  Status  (New / In Progress / Review / Done)
      '',                             // W  Assigned to
      ''                              // X  Notes
    ]);

    return ContentService
      .createTextOutput(JSON.stringify({ ok: true, ticketId: ticketId }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}
