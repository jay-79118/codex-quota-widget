'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const ROOT = path.join(os.homedir(), '.codex', 'sessions');
const TASK_CACHE = path.join(process.env.LOCALAPPDATA || os.tmpdir(),
  'CodexQuotaWidget', 'task-cache.json');

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

function requestAppServer(method, params, timeoutMs = 9000) {
  return new Promise((resolve, reject) => {
    const child = spawn(findCodex(), ['app-server', '--stdio'], {
      stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true,
    });
    let buffer = '';
    let errorText = '';
    let finished = false;
    const timer = setTimeout(() => finish(new Error('Codex 接口响应超时')), timeoutMs);

    function finish(error, result) {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      child.stdin.end();
      child.kill();
      if (error) reject(error);
      else resolve(result);
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
          child.stdin.write(JSON.stringify({ method, id: 2, params }) + '\n');
        } else if (response.id === 2) {
          if (response.error) return finish(new Error(response.error.message || 'Codex 接口读取失败'));
          finish(null, response.result || null);
        }
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

function readTasks(root = ROOT, cachePath = TASK_CACHE) {
  let cache = { version: 1, files: {} };
  try {
    const saved = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
    if (saved.version === 1 && saved.files && typeof saved.files === 'object') cache = saved;
  } catch { /* A missing or damaged cache is rebuilt from session files. */ }
  const nextFiles = {};
  let changed = false;
  const tasks = new Map();
  for (const file of listSessionFiles(root)) {
    const key = path.relative(root, file.path);
    let entry = cache.files[key];
    if (!entry || entry.size !== file.size || entry.modified !== file.modified) {
      let id = null;
      let usage = null;
      try {
        const meta = JSON.parse(readHeadLine(file.path));
        id = meta?.type === 'session_meta' ? meta.payload?.id : null;
        if (id) usage = latestTokenEvent(file.path, file.size);
      } catch { /* An incomplete session is retried after it changes. */ }
      entry = { size: file.size, modified: file.modified, id, usage };
      changed = true;
    }
    nextFiles[key] = entry;
    if (!entry.id || !entry.usage) continue;
    const previous = tasks.get(entry.id);
    const total = Number(entry.usage.total_tokens || 0);
    if (!previous || total > previous.totalTokens ||
        (total === previous.totalTokens && file.modified > previous.modified)) {
      tasks.set(entry.id, {
        id: entry.id,
        title: `任务 ${new Date(file.modified).toLocaleDateString('zh-CN')}`,
        totalTokens: total,
        inputTokens: Number(entry.usage.input_tokens || 0),
        cachedInputTokens: Number(entry.usage.cached_input_tokens || 0),
        outputTokens: Number(entry.usage.output_tokens || 0),
        reasoningOutputTokens: Number(entry.usage.reasoning_output_tokens || 0),
        modified: file.modified,
      });
    }
  }
  if (Object.keys(nextFiles).length !== Object.keys(cache.files).length) changed = true;
  if (changed) {
    try {
      fs.mkdirSync(path.dirname(cachePath), { recursive: true });
      fs.writeFileSync(cachePath, JSON.stringify({ version: 1, files: nextFiles }));
    } catch { /* Token details remain usable when the cache cannot be saved. */ }
  }
  return [...tasks.values()].sort((a, b) => b.modified - a.modified);
}

function quotaWindow(value) {
  if (!value || !Number.isFinite(value.usedPercent)) return null;
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

async function main(mode = 'quota') {
  if (mode === 'quota') {
    const limitsResponse = await requestAppServer('account/rateLimits/read');
    const limits = limitsResponse?.rateLimitsByLimitId?.codex ||
      limitsResponse?.rateLimits || null;
    return {
      checkedAt: Date.now(),
      quota: {
        primary: quotaWindow(limits?.primary),
        secondary: quotaWindow(limits?.secondary),
        error: null,
      },
    };
  }
  if (mode === 'tasks') {
    const namesRequest = requestAppServer('thread/list',
      { limit: 200, sortKey: 'updated_at' }, 6000).catch(() => null);
    const tasks = readTasks();
    const names = new Map();
    for (const row of (await namesRequest)?.data || []) {
      if (row?.id && row?.name && !names.has(row.id)) names.set(row.id, row.name);
    }
    return {
      checkedAt: Date.now(),
      tasks: tasks.map(task => ({ ...task,
        title: displayTitle(names.get(task.id) || task.title, task.id) })),
    };
  }
  throw new Error('未知读取模式');
}

if (require.main === module) {
  const mode = process.argv[2] || 'quota';
  main(mode).then(output => process.stdout.write(JSON.stringify(output)))
    .catch(error => process.stdout.write(JSON.stringify(mode === 'tasks'
      ? { checkedAt: Date.now(), tasks: [], error: error.message }
      : { checkedAt: Date.now(), quota: { primary: null, secondary: null,
        error: error.message } })));
}

module.exports = { readTasks, quotaWindow };
