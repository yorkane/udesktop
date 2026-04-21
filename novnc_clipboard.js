/**
 * noVNC Seamless Clipboard Bridge v5
 * Works on HTTP (non-secure context) without Clipboard API.
 *
 * KEY INSIGHT: We must NOT call preventDefault() on the keydown event.
 * We only stopImmediatePropagation() to prevent noVNC from seeing it,
 * then focus a hidden textarea so the browser naturally fires the paste
 * event on it. This is the only reliable way to read clipboard on HTTP.
 */
(function () {
  "use strict";

  // ---- Helpers ----

  function getCanvas() {
    return (
      document.querySelector("#noVNC_container canvas") ||
      document.querySelector("canvas")
    );
  }

  function getClipboardTextarea() {
    return document.getElementById("noVNC_clipboard_text");
  }

  function pushTextToVnc(text) {
    // Primary: noVNC's clipboard textarea (triggers internal VNC clipboard sync)
    var ta = getClipboardTextarea();
    if (ta) {
      ta.value = text;
      ta.dispatchEvent(new Event("change", { bubbles: true }));
    }
    // Bonus: rfb API if available
    try {
      if (window.UI && window.UI.rfb && window.UI.rfb.clipboardPasteFrom) {
        window.UI.rfb.clipboardPasteFrom(text);
      }
    } catch (e) {}
  }

  function simulateCtrlV() {
    try {
      if (window.UI && window.UI.rfb) {
        var rfb = window.UI.rfb;
        rfb.sendKey(0xffe3, "ControlLeft", true);
        rfb.sendKey(0x0076, "KeyV", true);
        rfb.sendKey(0x0076, "KeyV", false);
        rfb.sendKey(0xffe3, "ControlLeft", false);
        return;
      }
    } catch (e) {}
  }

  function refocusCanvas() {
    var canvas = getCanvas();
    if (canvas) canvas.focus({ preventScroll: true });
  }

  // ---- Hidden Paste Receiver ----

  var pasteReceiver = document.createElement("textarea");
  pasteReceiver.style.cssText =
    "position:fixed;left:0;top:0;width:2px;height:2px;opacity:0.01;z-index:99999;";
  pasteReceiver.setAttribute("tabindex", "-1");
  pasteReceiver.setAttribute("aria-hidden", "true");
  pasteReceiver.id = "_novnc_paste_recv";

  function ensurePasteReceiver() {
    if (!pasteReceiver.parentNode && document.body) {
      document.body.appendChild(pasteReceiver);
    }
  }

  // Ensure it's in the DOM
  if (document.body) {
    ensurePasteReceiver();
  } else {
    document.addEventListener("DOMContentLoaded", ensurePasteReceiver);
  }

  // ---- Permanent paste listener on our textarea ----

  pasteReceiver.addEventListener(
    "paste",
    function (e) {
      var text = "";
      if (e.clipboardData) {
        text = e.clipboardData.getData("text/plain");
      } else if (window.clipboardData) {
        text = window.clipboardData.getData("Text");
      }

      if (text) {
        console.log("[Clipboard] Pasted:", text.length, "chars");
        pushTextToVnc(text);
        setTimeout(simulateCtrlV, 30);
      }

      // Refocus canvas after a short delay
      setTimeout(refocusCanvas, 80);

      e.preventDefault();
      e.stopPropagation();
    },
    false
  );

  // ---- Ctrl+V Interception ----
  // CRITICAL: Do NOT call e.preventDefault() here!
  // We only stopImmediatePropagation to block noVNC, then focus our textarea.
  // The browser will naturally fire a 'paste' event on the focused textarea.

  document.addEventListener(
    "keydown",
    function (e) {
      if (!(e.ctrlKey || e.metaKey)) return;
      if (e.key !== "v" && e.key !== "V" && e.keyCode !== 86) return;

      // Stop noVNC from seeing this Ctrl+V
      e.stopImmediatePropagation();
      e.stopPropagation();
      // Do NOT call e.preventDefault() - let browser fire paste event!

      // Focus our hidden textarea so the paste event lands on it
      ensurePasteReceiver();
      pasteReceiver.value = "";
      pasteReceiver.focus({ preventScroll: true });

      // The browser will now process the Ctrl+V naturally and fire
      // a 'paste' event on our focused pasteReceiver textarea.
      // Our paste listener above will handle it.
    },
    true // capture phase - runs before noVNC
  );

  // ---- VNC -> Browser (clipboard poll) ----

  var lastVncClipboard = "";
  setInterval(function () {
    var ta = getClipboardTextarea();
    if (!ta || ta.value === lastVncClipboard) return;
    lastVncClipboard = ta.value;
    if (!lastVncClipboard) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(lastVncClipboard).catch(function () {});
    }
  }, 500);

  // ---- Ready ----
  console.log("[Clipboard] Bridge v5 loaded (HTTP-safe, no preventDefault).");
})();
