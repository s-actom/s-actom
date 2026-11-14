#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const target = process.argv[2];
if (!target) {
  throw new Error("Usage: validate-skill-runtime.mjs <transcript-or-session-directory>");
}

function jsonlFiles(root) {
  if (fs.statSync(root).isFile()) return [root];
  const result = [];
  const stack = [root];
  while (stack.length) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(full);
      else if (entry.isFile() && entry.name.endsWith(".jsonl")) result.push(full);
    }
  }
  return result.sort();
}

const results = [];
for (const file of jsonlFiles(target)) {
  const preloaded = new Set();
  const dynamic = [];
  let invalidLines = 0;
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    if (!line.trim()) continue;
    let record;
    try {
      record = JSON.parse(line);
    } catch {
      invalidLines += 1;
      continue;
    }
    const content = Array.isArray(record?.message?.content) ? record.message.content : [];
    if (record.isMeta === true) {
      for (const item of content) {
        if (item.type !== "text" || typeof item.text !== "string") continue;
        const name = item.text.match(/<command-name>([^<]+)<\/command-name>/)?.[1];
        if (name) preloaded.add(name);
      }
    }
    for (const item of content) {
      if (item.type === "tool_use" && item.name === "Skill") {
        dynamic.push(
          item.input?.skill ||
            item.input?.name ||
            item.input?.command ||
            "<unknown-skill-input>",
        );
      }
    }
  }
  if (preloaded.size || dynamic.length || file.includes(`${path.sep}subagents${path.sep}`)) {
    results.push({
      file,
      preloaded: [...preloaded],
      dynamic,
      invalidLines,
    });
  }
}

const summary = {
  filesInspected: jsonlFiles(target).length,
  filesReported: results.length,
  totalPreloaded: results.reduce((sum, item) => sum + item.preloaded.length, 0),
  totalDynamic: results.reduce((sum, item) => sum + item.dynamic.length, 0),
  results,
};

process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
