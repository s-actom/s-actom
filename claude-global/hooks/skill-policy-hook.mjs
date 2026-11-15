#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

let raw = "";
for await (const chunk of process.stdin) raw += chunk;

let input = {};
try {
  input = JSON.parse(raw || "{}");
} catch {
  process.exit(0);
}

const event = input.hook_event_name;
const claudeRoot = path.join(os.homedir(), ".claude");

function frontmatter(text) {
  return text.match(/^---\s*\n([\s\S]*?)\n---(?:\s*\n|$)/)?.[1] || "";
}

function list(fm, key) {
  const lines = fm.split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^${key}:`).test(line));
  if (start < 0) return [];
  const first = lines[start].replace(new RegExp(`^${key}:\\s*`), "").trim();
  if (first.startsWith("[") && first.endsWith("]")) {
    return [...first.matchAll(/["']([^"']+)["']/g)].map((match) => match[1]);
  }
  const result = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    const match = lines[index].match(/^\s*-\s+(.*?)\s*$/);
    if (!match) {
      if (/^[A-Za-z][\w-]*:/.test(lines[index])) break;
      continue;
    }
    result.push(match[1].replace(/^["']|["']$/g, ""));
  }
  return result;
}

function findAgent(agentType) {
  const safeAgentType = /^[A-Za-z0-9_-]+$/.test(agentType) ? agentType : "";
  const direct = path.join(claudeRoot, "agents", `${safeAgentType}.md`);
  if (safeAgentType && fs.existsSync(direct)) return direct;
  const directory = path.join(claudeRoot, "agents");
  if (!fs.existsSync(directory)) return null;
  for (const file of fs.readdirSync(directory)) {
    if (!file.endsWith(".md")) continue;
    const candidate = path.join(directory, file);
    const fm = frontmatter(fs.readFileSync(candidate, "utf8"));
    const name = fm.match(/^name:\s*["']?([^"'\n]+)["']?\s*$/m)?.[1]?.trim();
    if (name === safeAgentType) return candidate;
  }
  return null;
}

let additionalContext = "";
if (event === "SessionStart") {
  additionalContext =
    "Skill runtime policy: for every non-trivial task, select and apply at least one materially relevant installed skill before acting. In the main thread, invoke relevant discovered skills through the Skill tool. If no installed skill applies, record NO_RELEVANT_SKILL with a concrete reason. A subagent skill listed in frontmatter is preloaded automatically and does not require a Skill tool call. CLAUDE SECURITY (on request only): do not ask the owner to run /claude-security and do not emit OWNER_ACTION_REQUIRED questions about it on your own; the owner asks for a scan when they want one. Without a current report tied to the revision and scope, do not claim SECURE, CLEAN, security PASS, release-ready, or deploy-ready; just say no scan was run. Scan changes covers committed diffs only; use Scan codebase for a dirty working tree.";
} else if (event === "SubagentStart") {
  const agentType = /^[A-Za-z0-9_-]+$/.test(input.agent_type || "")
    ? input.agent_type
    : "unknown-agent";
  const agentFile = findAgent(agentType);
  const skills = agentFile ? list(frontmatter(fs.readFileSync(agentFile, "utf8")), "skills") : [];
  additionalContext = skills.length
    ? `Skill runtime policy for ${agentType}: these skills are already PRELOADED in your startup context: ${skills.join(", ")}. Apply the relevant preloaded instructions during this task. If your tools include Skill, invoke an additional unlisted installed skill only when materially relevant. In the final result distinguish PRELOADED_APPLIED, DYNAMIC_INVOKED, and NOT_USED_WITH_REASON. CLAUDE SECURITY (on request only): do not ask for or require a scan; do not claim SECURE, CLEAN, security PASS, release-ready, or deploy-ready without a current Claude Security report.`
    : `Skill runtime policy warning for ${agentType}: no preloaded skills could be resolved. Do not silently proceed on a non-trivial task; use Skill if available or report NO_RELEVANT_SKILL with a concrete reason. CLAUDE SECURITY (on request only): do not ask for or require a scan; do not claim SECURE, CLEAN, security PASS, release-ready, or deploy-ready without a current Claude Security report.`;
}

if (additionalContext) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: event,
        additionalContext,
      },
    }),
  );
}
