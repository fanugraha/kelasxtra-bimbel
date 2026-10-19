import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

// Catatan dikirim lewat petugas resmi hermesops (catatan_sync.py), bukan disalin mentah:
// ia membuat frontmatter (draft, tak-tepercaya), menolak rahasia & data pribadi, lalu commit lewat vault_commit.py.
const SYNC = join(homedir(), "hermesops", "scripts", "catatan_sync.py");

export const VaultSync = async ({ worktree }) => {
  let running = null;

  function run() {
    return new Promise((resolve) => {
      execFile("python3", ["-I", SYNC, worktree], { timeout: 120_000 }, (err, stdout, stderr) => {
        const out = `${stdout}${stderr}`.trim();
        if (err) console.error(`[vault-sync] petugas catatan gagal (catatan tetap aman di folder catatan/): ${err.message}`);
        else if (/DITOLAK|GAGAL/.test(out)) console.error(`[vault-sync]\n${out}`);
        resolve();
      });
    });
  }

  async function sync() {
    try {
      await access(SYNC);
    } catch {
      return;
    }
    if (!running) running = run().finally(() => (running = null));
    await running;
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") await sync();
    },
    dispose: sync,
  };
};
