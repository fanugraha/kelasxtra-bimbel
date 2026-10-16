import { readdir, readFile, stat, mkdir, copyFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, basename } from "node:path";

const VAULT = join(homedir(), "hermesops", "knowledge", "inbox", "catatan");

const SECRET = /(-----BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{16,}|password\s*[:=]\s*\S+|bearer\s+[A-Za-z0-9._-]{20,}|eyJ[A-Za-z0-9_-]{20,}\.)/i;

export const VaultSync = async ({ worktree }) => {
  const project = basename(worktree).toLowerCase().replace(/\s+/g, "-");
  const src = join(worktree, "catatan");
  const dest = join(VAULT, project);

  async function sync() {
    let files;
    try {
      files = await readdir(src);
    } catch {
      return;
    }
    await mkdir(dest, { recursive: true });
    for (const f of files) {
      if (!f.endsWith(".md")) continue;
      const s = join(src, f);
      const d = join(dest, f);
      try {
        const [ss, ds] = await Promise.all([stat(s), stat(d).catch(() => null)]);
        if (ds && ds.mtimeMs >= ss.mtimeMs) continue;
        const text = await readFile(s, "utf8");
        if (SECRET.test(text)) {
          console.error(`[vault-sync] lewati ${f}: terdeteksi pola rahasia`);
          continue;
        }
        await copyFile(s, d);
      } catch (e) {
        console.error(`[vault-sync] gagal ${f}:`, e.message);
      }
    }
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") await sync();
    },
    dispose: sync,
  };
};
