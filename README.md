# Duplicate-Download-Deleter

==========================

WHAT IT DOES
------------
- Watches your main Downloads folder deletes duplicate files as soon as downloaded keeping the newest
- Keeps the newest Chrome-style duplicate.
- Deletes older copies such as:
    file.zip
    file (1).zip
    file (2).zip
- Ignores unfinished .download files.
- Runs a periodic backup check every 20 seconds.
- Writes deleted-file activity to cleaner.log.

HOW TO USE (GUI - recommended)
------------------------------
1. Double-click "Launch GUI.bat"
   (or right-click DuplicateDownloadDeleter-GUI.ps1 → Run with PowerShell)

In the GUI you can:
  • Start Silently   – launches the cleaner with no visible window
  • Stop Cleaner     – stops the background process
  • Add to Startup   – checkbox to run the cleaner silently every time Windows starts
  • Open Log         – view cleaner.log

COMMAND-LINE / MANUAL
---------------------
Start silently:   double-click  Start Silently.bat
Stop:             double-click  Stop Cleaner.bat

START WITH WINDOWS (manual method)
----------------------------------
1. Press Win + R
2. Type: shell:startup
3. Create a shortcut to "Start Silently.bat" (or use the GUI checkbox)

NOTES
-----
- The cleaner itself always runs hidden (no PowerShell window).
- Closing the GUI does NOT stop the cleaner.
- Requires Windows PowerShell (built into Windows).
