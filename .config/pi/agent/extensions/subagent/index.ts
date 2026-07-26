import { spawn } from "node:child_process";
import {
  closeSync,
  constants,
  existsSync,
  fstatSync,
  lstatSync,
  openSync,
  readdirSync,
  readSync,
  realpathSync,
  type Dirent,
} from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { type Api, type Model } from "@earendil-works/pi-ai";
import {
  CONFIG_DIR_NAME,
  getAgentDir,
  parseFrontmatter,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MAX_TASKS = 8;
const MAX_CONCURRENCY = 4;
const MAX_OUTPUT_BYTES = 50 * 1024;
const MAX_AGENT_FILE_BYTES = 256 * 1024;
const DEFAULT_TOOLS = ["read", "bash", "edit", "write", "grep", "find", "ls"];

interface AgentDefinition {
  name: string;
  description: string;
  systemPrompt: string;
  tools: string[];
  model?: string;
  source: "user" | "project";
}

interface AgentResult {
  agent: string;
  task: string;
  output: string;
  exitCode: number;
  stderr: string;
  stopReason?: string;
  errorMessage?: string;
  model?: string;
  requestedModel?: string;
  userRequestedModel?: string;
  configuredModel?: string;
  modelSource: "user" | "agent" | "parent";
  usedParentModelFallback: boolean;
}

const THINKING_LEVELS = new Set([
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

interface ResolvedAgentModel {
  argument: string;
  requested?: string;
  userRequested?: string;
  configured?: string;
  source: "user" | "agent" | "parent";
  usedParentFallback: boolean;
}

function findExactModel(
  reference: string,
  availableModels: Model<Api>[],
): Model<Api> | undefined {
  const normalized = reference.trim().toLowerCase();
  if (!normalized) return undefined;

  const canonicalMatches = availableModels.filter(
    (model) => `${model.provider}/${model.id}`.toLowerCase() === normalized,
  );
  if (canonicalMatches.length === 1) return canonicalMatches[0];

  const idMatches = availableModels.filter(
    (model) => model.id.toLowerCase() === normalized,
  );
  return idMatches.length === 1 ? idMatches[0] : undefined;
}

function resolveModelReference(
  reference: string,
  availableModels: Model<Api>[],
): string | undefined {
  const requested = reference.trim();
  if (!requested) return undefined;

  let matched = findExactModel(requested, availableModels);
  let thinkingSuffix = "";
  if (!matched) {
    const colonIndex = requested.lastIndexOf(":");
    const suffix = requested.slice(colonIndex + 1);
    if (colonIndex !== -1 && THINKING_LEVELS.has(suffix)) {
      matched = findExactModel(requested.slice(0, colonIndex), availableModels);
      if (matched) thinkingSuffix = `:${suffix}`;
    }
  }
  return matched
    ? `${matched.provider}/${matched.id}${thinkingSuffix}`
    : undefined;
}

function resolveAgentModel(
  userRequestedModel: string | undefined,
  configuredModel: string | undefined,
  availableModels: Model<Api>[],
  parentModel: Model<Api>,
): ResolvedAgentModel {
  const userRequested = userRequestedModel?.trim() || undefined;
  const configured = configuredModel?.trim() || undefined;

  if (userRequested) {
    const argument = resolveModelReference(userRequested, availableModels);
    if (argument) {
      return {
        argument,
        requested: userRequested,
        userRequested,
        configured,
        source: "user",
        usedParentFallback: false,
      };
    }
  }

  if (configured) {
    const argument = resolveModelReference(configured, availableModels);
    if (argument) {
      return {
        argument,
        requested: configured,
        userRequested,
        configured,
        source: "agent",
        usedParentFallback: false,
      };
    }
  }

  return {
    argument: `${parentModel.provider}/${parentModel.id}`,
    requested: userRequested ?? configured,
    userRequested,
    configured,
    source: "parent",
    usedParentFallback: true,
  };
}

function truncate(text: string): string {
  if (Buffer.byteLength(text, "utf8") <= MAX_OUTPUT_BYTES) return text;
  const marker = "\n\n[Output truncated at 50 KB.]";
  const contentLimit = MAX_OUTPUT_BYTES - Buffer.byteLength(marker, "utf8");
  let value = text.slice(0, contentLimit);
  while (Buffer.byteLength(value, "utf8") > contentLimit)
    value = value.slice(0, -1);
  return `${value}${marker}`;
}

function readAgentFile(
  filePath: string,
  source: AgentDefinition["source"],
): string | undefined {
  const noFollow = source === "project" ? constants.O_NOFOLLOW : 0;
  let fileDescriptor: number | undefined;
  try {
    fileDescriptor = openSync(filePath, constants.O_RDONLY | noFollow);
    const stats = fstatSync(fileDescriptor);
    if (!stats.isFile() || stats.size > MAX_AGENT_FILE_BYTES) return undefined;

    const content = Buffer.alloc(stats.size);
    let offset = 0;
    while (offset < content.length) {
      const bytesRead = readSync(
        fileDescriptor,
        content,
        offset,
        content.length - offset,
        offset,
      );
      if (bytesRead === 0) break;
      offset += bytesRead;
    }
    return content.subarray(0, offset).toString("utf8");
  } catch {
    return undefined;
  } finally {
    if (fileDescriptor !== undefined) closeSync(fileDescriptor);
  }
}

function loadAgents(
  directory: string,
  source: AgentDefinition["source"],
): AgentDefinition[] {
  if (!existsSync(directory)) return [];
  const agents: AgentDefinition[] = [];

  let entries: Dirent[];
  try {
    entries = readdirSync(directory, { withFileTypes: true });
  } catch {
    return [];
  }

  for (const entry of entries) {
    if (!entry.name.endsWith(".md")) continue;
    if (!entry.isFile() && !entry.isSymbolicLink()) continue;
    if (source === "project" && entry.isSymbolicLink()) continue;

    const filePath = join(directory, entry.name);
    try {
      const content = readAgentFile(filePath, source);
      if (content === undefined) continue;
      const { frontmatter, body } = parseFrontmatter<Record<string, string>>(
        content,
      );
      if (!frontmatter.name || !frontmatter.description || !body.trim())
        continue;
      const configuredTools = frontmatter.tools
        ?.split(",")
        .map((tool) => tool.trim())
        .filter(Boolean);
      const tools = configuredTools?.length ? configuredTools : DEFAULT_TOOLS;
      agents.push({
        name: frontmatter.name,
        description: frontmatter.description,
        systemPrompt: body.trim(),
        tools,
        model: frontmatter.model,
        source,
      });
    } catch {
      // One malformed definition must not disable the extension.
    }
  }
  return agents;
}

function findProjectAgents(cwd: string): string | undefined {
  const candidate = join(resolve(cwd), CONFIG_DIR_NAME, "agent", "agents");
  try {
    const stats = lstatSync(candidate);
    const userAgentsDir = join(getAgentDir(), "agents");
    const duplicatesUserDirectory =
      existsSync(userAgentsDir) &&
      realpathSync(candidate) === realpathSync(userAgentsDir);
    if (
      stats.isDirectory() &&
      !stats.isSymbolicLink() &&
      !duplicatesUserDirectory
    ) {
      return candidate;
    }
  } catch {
    // The current working directory has no project-level agents.
  }
  return undefined;
}

function discoverAgents(projectDir?: string): AgentDefinition[] {
  const agents = new Map<string, AgentDefinition>();
  for (const agent of loadAgents(join(getAgentDir(), "agents"), "user"))
    agents.set(agent.name, agent);

  if (projectDir) {
    for (const agent of loadAgents(projectDir, "project"))
      agents.set(agent.name, agent);
  }
  return [...agents.values()];
}

function getInvocation(args: string[]): { command: string; args: string[] } {
  const script = process.argv[1];
  if (script && existsSync(script) && !script.startsWith("/$bunfs/")) {
    return { command: process.execPath, args: [script, ...args] };
  }
  return { command: "pi", args };
}

async function runAgent(
  agent: AgentDefinition,
  resolvedModel: ResolvedAgentModel,
  task: string,
  cwd: string,
  signal?: AbortSignal,
  onProgress?: (text: string) => void,
): Promise<AgentResult> {
  const tempDir = await mkdtemp(join(tmpdir(), "pi-subagent-"));
  const promptPath = join(
    tempDir,
    `${agent.name.replace(/[^a-z0-9_-]/gi, "_")}.md`,
  );
  try {
    await writeFile(promptPath, agent.systemPrompt, {
      encoding: "utf8",
      mode: 0o600,
    });

    const args = [
      "--mode",
      "json",
      "-p",
      "--no-session",
      "--tools",
      agent.tools.join(","),
    ];
    args.push("--model", resolvedModel.argument);
    args.push("--append-system-prompt", promptPath, `Task: ${task}`);

    return await new Promise<AgentResult>((resolveResult) => {
      const invocation = getInvocation(args);
      const child = spawn(invocation.command, invocation.args, {
        cwd,
        detached: process.platform !== "win32",
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
      });
      const messages: string[] = [];
      let stderr = "";
      let buffer = "";
      let stopReason: string | undefined;
      let errorMessage: string | undefined;
      let model: string | undefined;
      let aborted = false;
      let killTimer: ReturnType<typeof setTimeout> | undefined;

      const consume = (line: string) => {
        try {
          const event = JSON.parse(line) as {
            type?: string;
            message?: {
              role?: string;
              content?: Array<{ type?: string; text?: string }>;
              stopReason?: string;
              errorMessage?: string;
              model?: string;
            };
          };
          if (
            event.type !== "message_end" ||
            event.message?.role !== "assistant"
          )
            return;
          const text =
            event.message.content
              ?.filter((part) => part.type === "text")
              .map((part) => part.text ?? "")
              .join("") ?? "";
          if (text) {
            messages.push(text);
            onProgress?.(text);
          }
          stopReason = event.message.stopReason ?? stopReason;
          errorMessage = event.message.errorMessage ?? errorMessage;
          model = event.message.model ?? model;
        } catch {
          // JSON mode can emit non-event diagnostics; stderr is retained separately.
        }
      };

      child.stdout.on("data", (chunk: Buffer) => {
        buffer += chunk.toString("utf8");
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) if (line.trim()) consume(line);
      });
      child.stderr.on("data", (chunk: Buffer) => {
        stderr = truncate(stderr + chunk.toString("utf8"));
      });
      child.on("close", (code) => {
        signal?.removeEventListener("abort", abort);
        if (killTimer) clearTimeout(killTimer);
        if (aborted) killTree("SIGKILL");
        if (buffer.trim()) consume(buffer);
        resolveResult({
          agent: agent.name,
          task,
          output: truncate(messages.at(-1) ?? ""),
          exitCode: aborted ? 130 : (code ?? 1),
          stderr,
          stopReason,
          errorMessage,
          model,
          requestedModel: resolvedModel.requested,
          userRequestedModel: resolvedModel.userRequested,
          configuredModel: resolvedModel.configured,
          modelSource: resolvedModel.source,
          usedParentModelFallback: resolvedModel.usedParentFallback,
        });
      });
      child.on("error", (error) => {
        stderr = truncate(`${stderr}\n${error.message}`);
      });

      const killTree = (killSignal: "SIGTERM" | "SIGKILL") => {
        if (process.platform !== "win32" && child.pid) {
          try {
            process.kill(-child.pid, killSignal);
            return;
          } catch {
            // Fall back to killing the direct child if its group is unavailable.
          }
        }
        if (process.platform === "win32" && child.pid && killSignal === "SIGKILL") {
          spawn(
            "taskkill",
            ["/pid", String(child.pid), "/t", "/f"],
            { stdio: "ignore", windowsHide: true },
          ).unref();
          return;
        }
        child.kill(killSignal);
      };
      const abort = () => {
        aborted = true;
        if (process.platform === "win32") {
          killTree("SIGKILL");
          return;
        }
        killTree("SIGTERM");
        killTimer = setTimeout(() => killTree("SIGKILL"), 5_000);
        killTimer.unref();
      };
      if (signal?.aborted) abort();
      else signal?.addEventListener("abort", abort, { once: true });
    });
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
}

async function runParallel<T>(
  items: T[],
  worker: (item: T, index: number) => Promise<void>,
): Promise<void> {
  let next = 0;
  await Promise.all(
    Array.from(
      { length: Math.min(MAX_CONCURRENCY, items.length) },
      async () => {
        while (next < items.length) {
          const index = next++;
          await worker(items[index], index);
        }
      },
    ),
  );
}

const Task = Type.Object({
  agent: Type.String({
    description: "Agent name from the installed agent definitions",
  }),
  task: Type.String({ description: "Self-contained task for this agent" }),
  model: Type.Optional(
    Type.String({
      description:
        "User-requested model override; takes priority over the agent default model",
    }),
  ),
  cwd: Type.Optional(
    Type.String({
      description: "Working directory; defaults to the current project",
    }),
  ),
});

export default function subagentExtension(pi: ExtensionAPI) {
  const installedAgents = loadAgents(join(getAgentDir(), "agents"), "user");
  const agentSummary = installedAgents.length
    ? installedAgents
        .map((agent) => `${agent.name}: ${agent.description}`)
        .join("; ")
    : "none";

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description:
      "Delegate isolated work to configured subagents. Use exactly one mode: agent + task, tasks for parallel work, or chain for sequential work using {previous}. " +
      "Agents are loaded from the user directory, then extended by the current project's approved .pi/agent/agents directory. " +
      "Model priority: user-requested model override, agent default model, then parent agent model. " +
      `Installed user agents: ${agentSummary}`,
    promptSnippet:
      "Delegate focused investigation, implementation, or review work to an isolated subagent",
    promptGuidelines: [
      "When the user specifies a model for delegated work, pass it through the subagent model field; the user-requested model has highest priority.",
    ],
    parameters: Type.Object({
      agent: Type.Optional(Type.String()),
      task: Type.Optional(Type.String()),
      model: Type.Optional(
        Type.String({
          description:
            "User-requested model override for single mode; highest model priority",
        }),
      ),
      tasks: Type.Optional(Type.Array(Task, { maxItems: MAX_TASKS })),
      chain: Type.Optional(Type.Array(Task, { maxItems: MAX_TASKS })),
    }),
    async execute(_id, params, signal, onUpdate, ctx) {
      const projectAgentsDir = findProjectAgents(ctx.cwd);
      let approvedProjectAgentsDir: string | undefined;
      if (projectAgentsDir && ctx.hasUI && ctx.isProjectTrusted()) {
        const approved = await ctx.ui.confirm(
          "Load project subagents?",
          `Project-controlled prompts will be loaded from: ${projectAgentsDir}`,
        );
        if (approved) approvedProjectAgentsDir = projectAgentsDir;
      }
      const agents = discoverAgents(approvedProjectAgentsDir);
      const single = Boolean(params.agent && params.task);
      const parallel = Boolean(params.tasks?.length);
      const chained = Boolean(params.chain?.length);
      if (Number(single) + Number(parallel) + Number(chained) !== 1) {
        throw new Error(
          "Provide exactly one of: agent + task, tasks, or chain.",
        );
      }
      if (!ctx.model) {
        throw new Error("Cannot run a subagent without a parent agent model.");
      }
      const parentModel = ctx.model;
      const availableModels = ctx.modelRegistry.getAvailable();

      const requested = single
        ? [params.agent!]
        : (params.tasks ?? params.chain ?? []).map((item) => item.agent);
      const resolveAgent = (name: string) => {
        const agent = agents.find((item) => item.name === name);
        if (!agent)
          throw new Error(
            `Unknown subagent "${name}". Available: ${agents.map((item) => item.name).join(", ") || "none"}.`,
          );
        return agent;
      };
      for (const name of requested) resolveAgent(name);
      const resolveModelForAgent = (
        name: string,
        userRequestedModel?: string,
      ) =>
        resolveAgentModel(
          userRequestedModel,
          resolveAgent(name).model,
          availableModels,
          parentModel,
        );

      const results: AgentResult[] = [];
      const isFailed = (result: AgentResult) =>
        result.exitCode !== 0 ||
        result.stopReason === "error" ||
        result.stopReason === "aborted";
      const run = async (
        item: { agent: string; task: string; model?: string; cwd?: string },
        resultIndex?: number,
        throwOnFailure = true,
      ) => {
        const result = await runAgent(
          resolveAgent(item.agent),
          resolveModelForAgent(item.agent, item.model),
          item.task,
          item.cwd ?? ctx.cwd,
          signal,
          (text) => {
            onUpdate?.({
              content: [
                { type: "text", text: `${item.agent}: ${truncate(text)}` },
              ],
              details: { results },
            });
          },
        );
        if (resultIndex === undefined) results.push(result);
        else results[resultIndex] = result;
        if (throwOnFailure && isFailed(result))
          throw new Error(
            `${item.agent} failed: ${result.errorMessage || result.stderr || result.output || "no output"}`,
          );
        return result;
      };

      if (single)
        await run({
          agent: params.agent!,
          task: params.task!,
          model: params.model,
        });
      else if (parallel) {
        await runParallel(params.tasks!, async (item, index) => {
          try {
            await run(item, index, false);
          } catch (error) {
            const failedModel = resolveModelForAgent(item.agent, item.model);
            results[index] = {
              agent: item.agent,
              task: item.task,
              output: "",
              exitCode: 1,
              stderr: "",
              errorMessage:
                error instanceof Error ? error.message : String(error),
              requestedModel: failedModel.requested,
              userRequestedModel: failedModel.userRequested,
              configuredModel: failedModel.configured,
              modelSource: failedModel.source,
              usedParentModelFallback: failedModel.usedParentFallback,
            };
          }
        });
      } else {
        let previous = "";
        for (const item of params.chain!) {
          const result = await run({
            ...item,
            task: item.task.replaceAll("{previous}", previous),
          });
          previous = result.output;
        }
      }

      const output =
        single || chained
          ? (results.at(-1)?.output ?? "(no output)")
          : `Parallel: ${results.filter((result) => !isFailed(result)).length}/${results.length} succeeded\n\n${results
              .map((result) => {
                const status = isFailed(result) ? "failed" : "completed";
                const resultOutput = isFailed(result)
                  ? result.errorMessage || result.stderr || result.output || "(no output)"
                  : result.output || "(no output)";
                return `### ${result.agent} (${status})\n${resultOutput}`;
              })
              .join("\n\n")}`;
      return {
        content: [{ type: "text", text: truncate(output) }],
        details: { results },
      };
    },
  });
}
