'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { readTasks, quotaWindow } = require('../data.js');

test('quota percentage is bounded and independent of task files', () => {
  assert.equal(quotaWindow({ usedPercent: 35 }).remainingPercent, 65);
  assert.equal(quotaWindow({ usedPercent: 120 }).remainingPercent, 0);
  assert.equal(quotaWindow({ usedPercent: NaN }), null);
  assert.equal(quotaWindow(null), null);
});

test('task cache reuses unchanged sessions and invalidates changed files', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-widget-test-'));
  try {
    const sessions = path.join(directory, 'sessions');
    fs.mkdirSync(sessions);
    const session = path.join(sessions, 'sample.jsonl');
    const cache = path.join(directory, 'task-cache.json');
    function writeSession(total) {
      fs.writeFileSync(session, [
        JSON.stringify({ type: 'session_meta', payload: { id: 'sample-task' } }),
        JSON.stringify({ type: 'event_msg', payload: { type: 'token_count',
          info: { total_token_usage: { total_tokens: total, input_tokens: 70,
            output_tokens: 30 } } } }),
      ].join('\n') + '\n');
    }
    writeSession(100);
    assert.equal(readTasks(sessions, cache)[0].totalTokens, 100);
    const saved = JSON.parse(fs.readFileSync(cache, 'utf8'));
    saved.files['sample.jsonl'].usage.total_tokens = 999;
    fs.writeFileSync(cache, JSON.stringify(saved));
    assert.equal(readTasks(sessions, cache)[0].totalTokens, 999);
    writeSession(200);
    const nextTime = new Date(Date.now() + 3000);
    fs.utimesSync(session, nextTime, nextTime);
    assert.equal(readTasks(sessions, cache)[0].totalTokens, 200);
    fs.unlinkSync(session);
    assert.deepEqual(readTasks(sessions, cache), []);
    assert.deepEqual(JSON.parse(fs.readFileSync(cache, 'utf8')).files, {});
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
