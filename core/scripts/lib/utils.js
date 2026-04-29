#!/usr/bin/env node
/**
 * Shared utilities for Claude Code hooks
 *
 * Cross-platform (Windows, macOS, Linux)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

function getClaudeDir() {
  return path.join(os.homedir(), '.claude');
}

function getSessionsDir() {
  return path.join(getClaudeDir(), 'sessions');
}

function getLearnedSkillsDir() {
  return path.join(getClaudeDir(), 'learned-skills');
}

function getTempDir() {
  const dir = path.join(getClaudeDir(), 'tmp');
  ensureDir(dir);
  return dir;
}

// ---------------------------------------------------------------------------
// Date / time helpers
// ---------------------------------------------------------------------------

function getDateString() {
  return new Date().toISOString().slice(0, 10);
}

function getTimeString() {
  return new Date().toISOString().slice(11, 19);
}

function getDateTimeString() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

function getSessionIdShort() {
  const sid = process.env.CLAUDE_SESSION_ID || 'unknown';
  return sid.slice(0, 8);
}

// ---------------------------------------------------------------------------
// Project helpers
// ---------------------------------------------------------------------------

function getProjectName() {
  try {
    const cwd = process.cwd();
    const name = path.basename(cwd);
    return name !== '/' ? name : 'root';
  } catch {
    return 'unknown';
  }
}

function isGitRepo() {
  try {
    execSync('git rev-parse --is-inside-work-tree', {
      stdio: 'pipe',
      windowsHide: true,
    });
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// File operations
// ---------------------------------------------------------------------------

function readFile(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

function writeFile(filePath, content) {
  try {
    fs.writeFileSync(filePath, content, 'utf8');
    return true;
  } catch {
    return false;
  }
}

function appendFile(filePath, content) {
  try {
    fs.appendFileSync(filePath, content, 'utf8');
    return true;
  } catch {
    return false;
  }
}

function ensureDir(dirPath) {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Git helpers
// ---------------------------------------------------------------------------

function getGitModifiedFiles(patterns) {
  try {
    const output = execSync('git diff --name-only HEAD 2>/dev/null', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
    });
    const files = output.trim().split('\n').filter(Boolean);

    if (!patterns || patterns.length === 0) return files;

    const regexes = patterns.map(p => new RegExp(p));
    return files.filter(f => regexes.some(r => r.test(f)));
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Search helpers
// ---------------------------------------------------------------------------

function findFiles(dir, pattern, options) {
  const results = [];
  const maxAge = (options && options.maxAge) || Infinity;
  const now = Date.now();
  const patternRe = wildcardToRegex(pattern);

  try {
    walk(dir);
  } catch {
    // Directory may not exist
  }

  function walk(currentDir) {
    let entries;
    try {
      entries = fs.readdirSync(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);

      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (patternRe.test(entry.name)) {
        try {
          const stat = fs.statSync(fullPath);
          const ageDays = (now - stat.mtimeMs) / (1000 * 60 * 60 * 24);
          if (ageDays <= maxAge) {
            results.push({ path: fullPath, mtime: stat.mtimeMs });
          }
        } catch {
          // Skip unreadable files
        }
      }
    }
  }

  // Sort by modification time descending
  results.sort((a, b) => b.mtime - a.mtime);
  return results;
}

function wildcardToRegex(pattern) {
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*/g, '.*')
    .replace(/\?/g, '.');
  return new RegExp(`^${escaped}$`);
}

function countInFile(filePath, pattern) {
  const content = readFile(filePath);
  if (!content) return 0;

  const matches = content.match(pattern);
  return matches ? matches.length : 0;
}

// ---------------------------------------------------------------------------
// Command execution
// ---------------------------------------------------------------------------

function runCommand(cmd) {
  try {
    const output = execSync(cmd, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
      timeout: 5000,
    });
    return { success: true, output: output.trim() };
  } catch (err) {
    return { success: false, output: '' };
  }
}

// ---------------------------------------------------------------------------
// Logging / output
// ---------------------------------------------------------------------------

function log(msg) {
  process.stderr.write(msg + '\n');
}

function output(msg) {
  process.stdout.write(msg + '\n');
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  getClaudeDir,
  getSessionsDir,
  getLearnedSkillsDir,
  getTempDir,
  getDateString,
  getTimeString,
  getDateTimeString,
  getSessionIdShort,
  getProjectName,
  isGitRepo,
  readFile,
  writeFile,
  appendFile,
  ensureDir,
  getGitModifiedFiles,
  findFiles,
  countInFile,
  runCommand,
  log,
  output,
};
