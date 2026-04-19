/**
 * noVNC Seamless Clipboard Bridge
 * Enables browser <-> VNC clipboard sync over HTTP (no Clipboard API needed).
 *
 * How it works:
 * - Ctrl+V: Intercepts before noVNC, lets browser fire paste event to read
 *   clipboard, sends text to VNC clipboard, then re-sends Ctrl+V to VNC.
 * - Ctrl+C: VNC clipboard changes appear in noVNC's clipboard panel textarea.
 *   If on HTTPS, also auto-copies to browser clipboard.
 */
(function () {
  "use strict";

  var CTRL_V_KEYSYM = 0x0076; // 'v'
  var CTRL_KEYSYM = 0xffe3; // Control_L

  // Find noVNC's RFB instance (tries multiple known locations)
  function getRfb() {
    // noVNC UI module stores it at UI.rfb
    if (window.UI && window.UI.rfb) return window.UI.rfb;
    // Some builds expose it directly
    if (window.rfb) return window.rfb;
    return null;
  }

  // Send clipboard text to VNC server via noVNC's clipboard textarea
  function sendClipboardToVnc(text) {
    // Method 1: Use the clipboard textarea (works with all noVNC versions)
    var ta = document.getElementById("noVNC_clipboard_text");
    if (ta) {
      ta.value = text;
      ta.dispatchEvent(new Event("change", { bubbles: true }));
    }
    // Method 2: Also try RFB API directly
    var rfb = getRfb();
    if (rfb && rfb.clipboardPasteFrom) {
      rfb.clipboardPasteFrom(text);
    }
  }

  // Send Ctrl+V keystroke to VNC session
  function sendCtrlVToVnc() {
    var rfb = getRfb();
    if (!rfb) return;
    try {
      rfb.sendKey(CTRL_KEYSYM, "ControlLeft", true); // Ctrl down
      rfb.sendKey(CTRL_V_KEYSYM, "KeyV", true); // V down
      rfb.sendKey(CTRL_V_KEYSYM, "KeyV", false); // V up
      rfb.sendKey(CTRL_KEYSYM, "ControlLeft", false); // Ctrl up
    } catch (e) {
      console.warn("[Clipboard] Failed to send Ctrl+V to VNC:", e);
    }
  }

  // --- Browser -> VNC clipboard ---

  var awaitingPaste = false;

  // Capture Ctrl+V BEFORE noVNC's keyboard handler
  document.addEventListener(
    "keydown",
    function (e) {
      if ((e.ctrlKey || e.metaKey) && (e.key === "v" || e.keyCode === 86)) {
        awaitingPaste = true;
        // Stop noVNC from handling this Ctrl+V (so browser fires paste event)
        e.stopImmediatePropagation();
        // Don't preventDefault - let browser trigger 'paste' event
      }
    },
    true
  ); // capture phase = runs first

  // Receive clipboard data from the paste event
  document.addEventListener(
    "paste",
    function (e) {
      if (!awaitingPaste) return;
      awaitingPaste = false;

      var text = (e.clipboardData || window.clipboardData).getData(
        "text/plain"
      );
      if (!text) return;

      // 1. Set VNC clipboard content
      sendClipboardToVnc(text);

      // 2. After a brief delay, send Ctrl+V to VNC so the app pastes
      setTimeout(sendCtrlVToVnc, 100);

      e.preventDefault();
    },
    true
  );

  // --- VNC -> Browser clipboard (best-effort, needs HTTPS for full support) ---

  // Monitor noVNC clipboard textarea for changes from VNC
  var lastVncClipboard = "";
  setInterval(function () {
    var ta = document.getElementById("noVNC_clipboard_text");
    if (!ta || ta.value === lastVncClipboard) return;
    lastVncClipboard = ta.value;
    if (!lastVncClipboard) return;

    // Try Clipboard API (only works on HTTPS / localhost)
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(lastVncClipboard).catch(function () {});
    }
  }, 500);

  console.log("[Clipboard] noVNC clipboard bridge loaded");
})();
