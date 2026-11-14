// Drives the Windows WebView2 sign-in window for windows_webview2_login_test.dart.
//
// The app under test must be launched with
//   WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=<port>
// so the embedded WebView2 exposes the Chrome DevTools Protocol.
//
// Usage: node windows_webview2_driver.mjs <port> <scenario>[,<scenario>...]
//   login   wait for the sign-in page, submit alice/alice, accept consent
//   cancel  wait for the sign-in page, then close the native window (WM_CLOSE)
import { spawnSync } from 'node:child_process';

const [port = '9222', sequence = 'login'] = process.argv.slice(2);
const scenarios = sequence.split(',');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (m) => console.log(`[driver ${new Date().toISOString()}] ${m}`);

async function targets() {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/json`);
    return (await res.json()).filter((t) => t.type === 'page');
  } catch {
    return [];
  }
}

async function waitForSignInPage(timeoutMs = 90000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const page = (await targets()).find((t) => /duendesoftware\.com/.test(t.url));
    if (page) return page;
    await sleep(250);
  }
  throw new Error('sign-in page never appeared');
}

async function waitForPageGone(id, timeoutMs = 60000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (!(await targets()).some((t) => t.id === id)) return true;
    await sleep(250);
  }
  return false;
}

class Cdp {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.id = 0;
    this.pending = new Map();
    this.ready = new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
    // A navigation (e.g. the login POST) tears the socket down; settle any
    // in-flight evaluation instead of leaving it pending forever.
    this.ws.onclose = () => {
      for (const p of this.pending.values()) p({});
      this.pending.clear();
    };
    this.ws.onmessage = (e) => {
      const m = JSON.parse(e.data);
      const p = this.pending.get(m.id);
      if (p) {
        this.pending.delete(m.id);
        p(m);
      }
    };
  }
  async eval(expression) {
    try {
      await this.ready;
    } catch {
      return undefined;
    }
    const id = ++this.id;
    const reply = new Promise((r) => this.pending.set(id, r));
    this.ws.send(JSON.stringify({ id, method: 'Runtime.evaluate', params: { expression, returnByValue: true } }));
    const timeout = new Promise((r) => setTimeout(() => r({}), 5000));
    return (await Promise.race([reply, timeout])).result?.result?.value;
  }
  close() {
    try { this.ws.close(); } catch {}
  }
}

async function submitCredentials(page) {
  const cdp = new Cdp(page.webSocketDebuggerUrl);
  try {
    const end = Date.now() + 60000;
    while (Date.now() < end) {
      const state = await cdp.eval(`(() => {
        const u = document.querySelector('#Input_Username, input[name="Input.Username"]');
        const p = document.querySelector('#Input_Password, input[name="Input.Password"]');
        const login = document.querySelector('button[value="login"]');
        if (u && p && login) {
          u.value = 'alice'; p.value = 'alice'; login.click(); return 'submitted-login';
        }
        const yes = document.querySelector('button[value="yes"]');
        if (yes) { yes.click(); return 'submitted-consent'; }
        return 'waiting:' + location.href;
      })()`);
      if (state && !state.startsWith('waiting')) log(state);
      if (!(await targets()).some((t) => t.id === page.id)) return;
      await sleep(500);
    }
  } finally {
    cdp.close();
  }
}

function closeNativeWindow() {
  // EnumWindows by class name: FindWindow(class, $null) marshals $null as ""
  // in PowerShell and would only match windows with an empty title.
  const script = `
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class WinClose {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static bool CloseByClass(string cls) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { var sb = new StringBuilder(256); GetClassName(h, sb, 256); if (sb.ToString() == cls) { found = h; return false; } return true; }, IntPtr.Zero);
    if (found == IntPtr.Zero) return false;
    return PostMessage(found, 0x0010, IntPtr.Zero, IntPtr.Zero);
  }
}
'@
if ([WinClose]::CloseByClass('OpenIdConnectWebAuthWindow')) { Write-Output 'closed' } else { Write-Output 'no-window'; exit 1 }`;
  const r = spawnSync('powershell', ['-NoProfile', '-Command', script], { encoding: 'utf8' });
  log(`WM_CLOSE: ${r.stdout.trim()}`);
  if (r.status !== 0) throw new Error('native auth window not found');
}

for (const [i, scenario] of scenarios.entries()) {
  log(`session ${i + 1}/${scenarios.length}: ${scenario}`);
  const page = await waitForSignInPage();
  log(`sign-in page: ${page.url.split('?')[0]}`);
  if (scenario === 'login') {
    await submitCredentials(page);
  } else if (scenario === 'cancel') {
    await sleep(1500);
    closeNativeWindow();
  } else {
    throw new Error(`unknown scenario ${scenario}`);
  }
  if (!(await waitForPageGone(page.id))) throw new Error('window did not close');
  log(`session ${i + 1} window closed`);
}
log('done');
