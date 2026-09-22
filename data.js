'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const ROOT = path.join(os.homedir(), '.codex', 'sessions');

function findCodex() {
  const binRoot = path.join(process.env.LOCALAPPDATA || '', 'OpenAI', 'Codex', 'bin');
  try {
    const candidates = fs.readdirSync(binRoot, { withFileTypes: true })
      .filter(entry => entry.isDirectory())
      .map(entry => path.join(binRoot, entry.name, 'codex.exe'))
      .filter(candidate => fs.existsSync(candidate))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
    if (candidates.length) return candidates[0];
  } catch { /* PATH fallback below */ }
  return 'codex';
}

function requestAppServer() {
  return new Promise((resolve, reject) => {
    const child = spawn(findCodex(), ['app-server', '--stdio'], {
      stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true,
    });
    let buffer = '';
    let errorText = '';
    let limits;
    let threads;
    let finished = false;
    const timer = setTimeout(() => finish(new Error('Codex 接口响应超时')), 9000);

    function finish(error) {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      child.stdin.end();
      child.kill();
      if (error) reject(error);
      else resolve({ limits, threads });
    }

    child.on('error', error => finish(error));
    child.on('exit', code => {
      if (!finished) finish(new Error(errorText.trim() || `Codex 接口退出 (${code})`));
    });
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', chunk => { errorText += chunk; });
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', chunk => {
      buffer += chunk;
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end).trim();
        buffer = buffer.slice(end + 1);
        if (!line) continue;
        let response;
        try { response = JSON.parse(line); } catch { continue; }
        if (response.id === 1) {
          if (response.error) return finish(new Error(response.error.message || '初始化失败'));
          child.stdin.write(JSON.stringify({ method: 'initialized', params: {} }) + '\n');
          child.stdin.write(JSON.stringify({ method: 'account/rateLimits/read', id: 2 }) + '\n');
          child.stdin.write(JSON.stringify({ method: 'thread/list', id: 3,
            params: { limit: 200, sortKey: 'updated_at' } }) + '\n');
        } else if (response.id === 2) {
          limits = response.result || null;
          if (response.error) limits = { error: response.error.message || '额度读取失败' };
        } else if (response.id === 3) {
          threads = response.result?.data || [];
        }
        if (limits !== undefined && threads !== undefined) finish();
      }
    });
    child.stdin.write(JSON.stringify({ method: 'initialize', id: 1,
      params: { clientInfo: { name: 'codex-quota-widget', version: '1.0.0' } },
    }) + '\n');
  });
}

function listSessionFiles(directory, result = []) {
  if (!fs.existsSync(directory)) return result;
  for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, item.name);
    if (item.isDirectory()) listSessionFiles(full, result);
    else if (item.isFile() && item.name.endsWith('.jsonl')) {
      const stat = fs.statSync(full);
      result.push({ path: full, modified: stat.mtimeMs, size: stat.size });
    }
  }
  return result;
}

function readHeadLine(file) {
  const fd = fs.openSync(file, 'r');
  try {
    const bytes = Buffer.alloc(65536);
    const length = fs.readSync(fd, bytes, 0, bytes.length, 0);
    return bytes.toString('utf8', 0, length).split('\n')[0];
  } finally { fs.closeSync(fd); }
}

function latestTokenEvent(file, size) {
  const fd = fs.openSync(file, 'r');
  try {
    for (let wanted = 256 * 1024; wanted <= Math.max(size, 256 * 1024); wanted *= 4) {
      const length = Math.min(size, wanted);
      const bytes = Buffer.alloc(length);
      fs.readSync(fd, bytes, 0, length, size - length);
      const lines = bytes.toString('utf8').split('\n');
      for (let i = lines.length - 1; i >= (size > length ? 1 : 0); i--) {
        if (!lines[i].includes('token_count')) continue;
        try {
          const row = JSON.parse(lines[i]);
          if (row.type === 'event_msg' && row.payload?.type === 'token_count' &&
              row.payload.info?.total_token_usage) return row.payload.info.total_token_usage;
        } catch { /* partial line */ }
      }
      if (length === size || length >= 16 * 1024 * 1024) break;
    }
  } finally { fs.closeSync(fd); }
  return null;
}

function readTasks(threadRows) {
  const names = new Map();
  for (const row of threadRows || []) {
    if (row?.id && row?.name && !names.has(row.id)) names.set(row.id, row.name);
  }
  const tasks = new Map();
  for (const file of listSessionFiles(ROOT)) {
    let meta;
    try { meta = JSON.parse(readHeadLine(file.path)); } catch { continue; }
    const id = meta?.type === 'session_meta' ? meta.payload?.id : null;
    if (!id) continue;
    let usage;
    try { usage = latestTokenEvent(file.path, file.size); } catch { continue; }
    if (!usage) continue;
    const previous = tasks.get(id);
    const total = Number(usage.total_tokens || 0);
    if (!previous || total > previous.totalTokens ||
        (total === previous.totalTokens && file.modified > previous.modified)) {
      tasks.set(id, {
        id,
        title: names.get(id) || `任务 ${new Date(file.modified).toLocaleDateString('zh-CN')}`,
        totalTokens: total,
        inputTokens: Number(usage.input_tokens || 0),
        cachedInputTokens: Number(usage.cached_input_tokens || 0),
        outputTokens: Number(usage.output_tokens || 0),
        reasoningOutputTokens: Number(usage.reasoning_output_tokens || 0),
        modified: file.modified,
      });
    }
  }
  return [...tasks.values()].sort((a, b) => b.modified - a.modified);
}

function quotaWindow(value) {
  if (!value || typeof value.usedPercent !== 'number') return null;
  return {
    usedPercent: Math.min(100, Math.max(0, value.usedPercent)),
    remainingPercent: Math.min(100, Math.max(0, 100 - value.usedPercent)),
    windowDurationMins: value.windowDurationMins,
    resetsAt: value.resetsAt,
  };
}

function displayTitle(title, id) {
  const value = String(title || '');
  if (/密码|账号\s*[:：]|密钥|password|api[ _-]?key|secret/i.test(value)) {
    return `私密任务 ${id.slice(0, 8)}`;
  }
  return value.slice(0, 100);
}

(async () => {
  let account;
  let quotaError = null;
  try { account = await requestAppServer(); }
  catch (error) { quotaError = error.message; }
  const limits = account?.limits?.rateLimitsByLimitId?.codex ||
    account?.limits?.rateLimits || null;
  if (account?.limits?.error) quotaError = account.limits.error;
  const output = {
    checkedAt: Date.now(),
    quota: {
      primary: quotaWindow(limits?.primary),
      secondary: quotaWindow(limits?.secondary),
      error: quotaError,
    },
    tasks: readTasks(account?.threads).map(task => ({
      ...task,
      title: displayTitle(task.title, task.id),
    })),
  };
  process.stdout.write(JSON.stringify(output));
})().catch(error => {
  process.stdout.write(JSON.stringify({
    checkedAt: Date.now(), quota: { primary: null, secondary: null,
      error: error.message }, tasks: [],
  }));
});
