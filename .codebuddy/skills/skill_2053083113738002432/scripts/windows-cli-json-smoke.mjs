#!/usr/bin/env node
/**
 * Windows / 无全局 node 环境下的 JSON CLI 冒烟。
 * 使用 process.execPath 调用脚本，验证 3.0 新增最小链路可跑。
 */

import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function run(relScript, args) {
  const full = path.join(ROOT, relScript);
  const result = spawnSync(process.execPath, [full, ...args], {
    cwd: ROOT,
    encoding: 'utf8',
  });
  return {
    status: typeof result.status === 'number' ? result.status : 1,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function parseJson(output, script) {
  try {
    return JSON.parse(output);
  } catch (error) {
    throw new Error(`${script} JSON 输出解析失败：${error.message}`);
  }
}

export function runWindowsCliJsonSmoke() {
  const fixtureDir = path.join(ROOT, 'fixtures', 'regression', 'post-draft');
  const bookRoot = path.join(ROOT, 'fixtures', 'ci-book-root');
  fs.mkdirSync(path.join(bookRoot, '.fbs'), { recursive: true });

  const layout = run('scripts/layout-preflight.mjs', [
    '--input',
    path.join(fixtureDir, 'sample-layout.md'),
    '--json',
  ]);
  if (layout.status !== 0) throw new Error(layout.stderr || 'layout-preflight 失败');

  const deAi = run('scripts/de-ai-diff.mjs', [
    '--before',
    path.join(fixtureDir, 'sample-before.md'),
    '--after',
    path.join(fixtureDir, 'sample-after.md'),
    '--strength',
    'medium',
    '--json',
  ]);
  if (deAi.status !== 0) throw new Error(deAi.stderr || 'de-ai-diff 失败');

  const event = run('scripts/event-writer.mjs', [
    '--book-root',
    bookRoot,
    '--event',
    'post_draft_action_click',
    '--benefit-source',
    'local_cache',
    '--member-tier',
    'T1',
    '--credits-state',
    'available',
    '--json',
  ]);
  if (event.status !== 0) throw new Error(event.stderr || 'event-writer 失败');

  return {
    ok: true,
    node: process.execPath,
    layout: parseJson(layout.stdout, 'layout-preflight'),
    deAi: parseJson(deAi.stdout, 'de-ai-diff'),
    event: parseJson(event.stdout, 'event-writer'),
  };
}

export function main() {
  try {
    const result = runWindowsCliJsonSmoke();
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    return 0;
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ ok: false, error: error.message }, null, 2)}\n`);
    return 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  process.exit(main());
}
