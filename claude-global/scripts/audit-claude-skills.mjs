#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const positionalArgs = process.argv.slice(2).filter((arg) => arg !== "--strict");
const strict = process.argv.includes("--strict");
const claudeRoot = positionalArgs[0] || path.join(os.homedir(), ".claude");
const outputPath = positionalArgs[1] || "";
const skillsRoot = positionalArgs[2] || claudeRoot;

function walk(root, predicate) {
  const result = [];
  if (!fs.existsSync(root)) return result;
  const stack = [root];
  const visitedDirectories = new Set();
  while (stack.length) {
    const current = stack.pop();
    let realCurrent;
    try {
      realCurrent = fs.realpathSync(current);
    } catch {
      continue;
    }
    if (visitedDirectories.has(realCurrent)) continue;
    visitedDirectories.add(realCurrent);
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      let stat;
      try {
        stat = entry.isSymbolicLink() ? fs.statSync(full) : null;
      } catch {
        continue;
      }
      if (entry.isDirectory() || stat?.isDirectory()) stack.push(full);
      else if ((entry.isFile() || stat?.isFile()) && predicate(full)) result.push(full);
    }
  }
  return result.sort();
}

function frontmatter(text) {
  const match = text.match(/^---\s*\n([\s\S]*?)\n---(?:\s*\n|$)/);
  return match ? match[1] : "";
}

function scalar(fm, key) {
  const match = fm.match(new RegExp(`^${key}:\\s*(.*?)\\s*$`, "m"));
  if (!match) return null;
  const value = match[1].trim();
  return value.replace(/^["']|["']$/g, "");
}

function parseList(fm, key) {
  const lines = fm.split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^${key}:`).test(line));
  if (start < 0) return null;
  const first = lines[start].replace(new RegExp(`^${key}:\\s*`), "").trim();
  function commaSeparated(inner) {
    const values = [];
    let token = "";
    let quote = null;
    let depth = 0;
    for (const char of inner) {
      if (quote) {
        token += char;
        if (char === quote) quote = null;
        continue;
      }
      if (char === '"' || char === "'") {
        quote = char;
        token += char;
      } else if (char === "(") {
        depth += 1;
        token += char;
      } else if (char === ")") {
        depth -= 1;
        token += char;
      } else if (char === "," && depth === 0) {
        values.push(token.trim().replace(/^["']|["']$/g, ""));
        token = "";
      } else {
        token += char;
      }
    }
    if (token.trim()) values.push(token.trim().replace(/^["']|["']$/g, ""));
    return values.filter(Boolean);
  }
  if (first.startsWith("[") && first.endsWith("]")) {
    return commaSeparated(first.slice(1, -1));
  }
  if (first) {
    return commaSeparated(first);
  }
  const values = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    const line = lines[index];
    const item = line.match(/^\s*-\s+(.*?)\s*$/);
    if (!item) {
      if (/^\w[\w-]*:/.test(line)) break;
      continue;
    }
    values.push(item[1].replace(/^["']|["']$/g, ""));
  }
  return values;
}

function skillName(skillPath) {
  const text = fs.readFileSync(skillPath, "utf8");
  const fm = frontmatter(text);
  return scalar(fm, "name") || path.basename(path.dirname(skillPath));
}

const agentDir = path.join(claudeRoot, "agents");
const agentFiles = walk(agentDir, (file) => file.endsWith(".md"));
const skillFiles = [
  ...walk(path.join(skillsRoot, "skills"), (file) => path.basename(file) === "SKILL.md"),
  ...walk(path.join(skillsRoot, "plugins", "cache"), (file) => path.basename(file) === "SKILL.md"),
  ...walk(path.join(skillsRoot, "plugins", "marketplaces"), (file) => path.basename(file) === "SKILL.md"),
];

const installedByName = new Map();
for (const skillPath of skillFiles) {
  const name = skillName(skillPath);
  for (const alias of new Set([name, path.basename(path.dirname(skillPath))])) {
    const paths = installedByName.get(alias) || [];
    paths.push(skillPath);
    installedByName.set(alias, paths);
  }
}

function resolveSkill(declared) {
  const split = declared.split(":");
  const shortName = split.length > 1 ? split.at(-1) : declared;
  const candidates = installedByName.get(shortName) || [];
  if (split.length === 1) {
    const preferred = candidates.filter((candidate) =>
      candidate.startsWith(path.join(skillsRoot, "skills") + path.sep),
    );
    return preferred[0] || candidates[0] || null;
  }
  const namespace = split.slice(0, -1).join(":").toLowerCase();
  return (
    candidates.find((candidate) => candidate.toLowerCase().includes(namespace)) ||
    candidates[0] ||
    null
  );
}

const agents = [];
for (const file of agentFiles) {
  const text = fs.readFileSync(file, "utf8");
  const fm = frontmatter(text);
  const tools = parseList(fm, "tools");
  const skills = parseList(fm, "skills");
  const bodySkillNames = [
    ...text.matchAll(/^\s*-\s+`([^`]+)`\s+[—-]/gm),
  ].map((match) => match[1]);
  const declared = skills || [];
  const unresolved = declared.filter((skill) => !resolveSkill(skill));
  const explicitTools = tools !== null;
  const hasDynamicSkillTool =
    !explicitTools || tools.some((tool) => tool === "Skill" || tool.startsWith("Skill("));
  agents.push({
    name: scalar(fm, "name") || path.basename(file, ".md"),
    file,
    model: scalar(fm, "model"),
    tools: tools || [],
    explicitTools,
    hasDynamicSkillTool,
    skillsDeclared: declared,
    skillsDeclaredCount: declared.length,
    unresolvedSkills: unresolved,
    bodySkillNames,
    bodyOnlySkills: bodySkillNames.filter((skill) => !declared.includes(skill)),
    hasAgentTool: (tools || []).some(
      (tool) => tool === "Agent" || tool.startsWith("Agent("),
    ),
  });
}

const declarations = agents.flatMap((agent) =>
  agent.skillsDeclared.map((skill) => ({
    agent: agent.name,
    skill,
    resolvedPath: resolveSkill(skill),
  })),
);

const report = {
  generatedAt: new Date().toISOString(),
  claudeRoot,
  skillsRoot,
  counts: {
    agents: agents.length,
    agentsWithSkillsFrontmatter: agents.filter((agent) => agent.skillsDeclaredCount > 0)
      .length,
    agentsWithoutSkillsFrontmatter: agents.filter(
      (agent) => agent.skillsDeclaredCount === 0,
    ).length,
    agentsWithDynamicSkillTool: agents.filter((agent) => agent.hasDynamicSkillTool).length,
    agentsWithoutDynamicSkillTool: agents.filter((agent) => !agent.hasDynamicSkillTool)
      .length,
    coordinatorAgents: agents.filter((agent) => agent.hasAgentTool).length,
    coordinatorsWithDynamicSkillTool: agents.filter(
      (agent) => agent.hasAgentTool && agent.hasDynamicSkillTool,
    ).length,
    declarations: declarations.length,
    unresolvedDeclarations: declarations.filter((item) => !item.resolvedPath).length,
    skillFiles: skillFiles.length,
    distinctSkillNames: installedByName.size,
    agentsWithBodyOnlySkillDocs: agents.filter((agent) => agent.bodyOnlySkills.length > 0)
      .length,
  },
  agents,
  declarations,
};

const json = JSON.stringify(report, null, 2);
if (outputPath) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${json}\n`);
}
process.stdout.write(
  `${JSON.stringify(report.counts, null, 2)}\n\n` +
    `Agents without frontmatter skills:\n${agents
      .filter((agent) => agent.skillsDeclaredCount === 0)
      .map((agent) => `- ${agent.name}`)
      .join("\n")}\n\n` +
    `Unresolved declarations:\n${declarations
      .filter((item) => !item.resolvedPath)
      .map((item) => `- ${item.agent}: ${item.skill}`)
    .join("\n")}\n`,
);

if (
  strict &&
  (report.counts.agentsWithoutSkillsFrontmatter !== 0 ||
    report.counts.unresolvedDeclarations !== 0 ||
    report.counts.coordinatorsWithDynamicSkillTool !== report.counts.coordinatorAgents)
) {
  process.exitCode = 1;
}
