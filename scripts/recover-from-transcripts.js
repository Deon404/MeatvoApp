/**
 * Focused recovery from the 3 agent sessions that created lost work.
 * Uses git HEAD as base for existing files, then replays session edits.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const REPO_ROOT = path.join(__dirname, '..');
const TRANSCRIPTS = [
  path.join(
    process.env.USERPROFILE,
    '.cursor/projects/c-project-MeatvoApp/agent-transcripts/a4b158f7-807c-4611-ad61-4b1881f29717/a4b158f7-807c-4611-ad61-4b1881f29717.jsonl'
  ),
  path.join(
    process.env.USERPROFILE,
    '.cursor/projects/c-project-MeatvoApp/agent-transcripts/bb46e415-2884-4a1a-9fbf-8ff05e89d6f9/bb46e415-2884-4a1a-9fbf-8ff05e89d6f9.jsonl'
  ),
  path.join(
    process.env.USERPROFILE,
    '.cursor/projects/c-project-MeatvoApp/agent-transcripts/635d79ca-ae99-4ab5-a5e7-ea12edd790d8/635d79ca-ae99-4ab5-a5e7-ea12edd790d8.jsonl'
  ),
];

const files = new Map();

function normalizePath(p) {
  if (!p) return null;
  let norm = p.replace(/\\/g, '/');
  const lower = norm.toLowerCase();
  const oldIdx = lower.indexOf('/old_meatvo/');
  if (oldIdx !== -1) norm = 'frontend' + norm.slice(oldIdx + '/old_meatvo'.length);
  const feIdx = lower.indexOf('/frontend/');
  if (feIdx !== -1) norm = norm.slice(norm.toLowerCase().indexOf('frontend/'));
  if (!norm.startsWith('frontend/')) return null;
  return norm;
}

function gitHeadContent(rel) {
  const gitPath = rel.replace(/^frontend\//, 'old_meatvo/');
  try {
    return execSync(`git show HEAD:"${gitPath}"`, {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
  } catch {
    return undefined;
  }
}

function getContent(rel) {
  if (files.has(rel)) return files.get(rel);
  const fromGit = gitHeadContent(rel);
  if (fromGit !== undefined) return fromGit;
  const abs = path.join(REPO_ROOT, rel);
  if (fs.existsSync(abs)) return fs.readFileSync(abs, 'utf8');
  return undefined;
}

function processToolUse(tool) {
  if (!tool?.name) return;
  const input = tool.input || {};

  if (tool.name === 'Write') {
    const rel = normalizePath(input.path);
    if (rel && typeof input.contents === 'string') files.set(rel, input.contents);
    return;
  }

  if (tool.name === 'StrReplace') {
    const rel = normalizePath(input.path);
    if (!rel) return;
    let content = getContent(rel);
    if (content === undefined) return;
    const { old_string: oldStr, new_string: newStr, replace_all: replaceAll } = input;
    if (typeof oldStr !== 'string' || typeof newStr !== 'string') return;
    if (!content.includes(oldStr)) return;
    files.set(
      rel,
      replaceAll ? content.split(oldStr).join(newStr) : content.replace(oldStr, newStr)
    );
  }
}

function processLine(line) {
  try {
    const obj = JSON.parse(line);
    for (const b of obj?.message?.content || []) {
      if (b?.type === 'tool_use') processToolUse(b);
    }
  } catch {}
}

for (const transcript of TRANSCRIPTS) {
  if (!fs.existsSync(transcript)) {
    console.warn('Missing:', transcript);
    continue;
  }
  for (const line of fs.readFileSync(transcript, 'utf8').split('\n')) {
    if (line.trim()) processLine(line);
  }
}

let written = 0;
const writtenPaths = [];

for (const [rel, content] of files.entries()) {
  const abs = path.join(REPO_ROOT, rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, content, 'utf8');
  written++;
  writtenPaths.push(rel);
}

console.log(`Recovered ${written} files from 3 focused sessions:`);
writtenPaths.sort().forEach((p) => console.log('  ' + p));
