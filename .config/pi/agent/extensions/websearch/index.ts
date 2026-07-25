/**
 * WebSearch Extension
 *
 * Registers two web search tools for the LLM:
 * - exa_search: Semantic search via Exa API (POST https://api.exa.ai/search)
 * - tavily_search: Web search via Tavily API (POST https://api.tavily.com/search)
 *
 * API keys are read directly from environment variables:
 *   EXA_API_KEY    - Get one at https://dashboard.exa.ai/api-keys
 *   TAVILY_API_KEY - Get one at https://app.tavily.com
 *
 * Alternatively, paste keys into MANUAL_API_KEYS below.
 * Environment variables take precedence over manually configured keys.
 *
 * Place in ~/.pi/agent/extensions/ for auto-discovery.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

type SearchProvider = "exa" | "tavily";

const API_KEY_ENV: Record<SearchProvider, "EXA_API_KEY" | "TAVILY_API_KEY"> = {
  exa: "EXA_API_KEY",
  tavily: "TAVILY_API_KEY",
};

// Optional: paste API keys here if you do not want to use environment variables.
const MANUAL_API_KEYS: Record<SearchProvider, string> = {
  exa: "",
  tavily: "",
};

function getApiKey(provider: SearchProvider): string | undefined {
  return process.env[API_KEY_ENV[provider]]?.trim() || MANUAL_API_KEYS[provider].trim() || undefined;
}

function missingKeyError(provider: SearchProvider): Error {
  const envName = API_KEY_ENV[provider];
  return new Error(
    `${envName} is not set. Set the environment variable or paste the ${provider} key into MANUAL_API_KEYS in websearch.ts.`,
  );
}

// ──────────────────────────────────────────────
// Helper: shared fetch with timeout
// ──────────────────────────────────────────────

async function fetchWithTimeout(
  url: string,
  options: RequestInit & { timeoutMs?: number },
  signal?: AbortSignal,
): Promise<Response> {
  const { timeoutMs = 30_000, ...fetchOptions } = options;
  const controller = new AbortController();
  let timedOut = false;

  const abortFromCaller = () => controller.abort(signal?.reason);
  if (signal?.aborted) {
    abortFromCaller();
  } else {
    signal?.addEventListener("abort", abortFromCaller, { once: true });
  }

  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);

  try {
    return await fetch(url, {
      ...fetchOptions,
      signal: controller.signal,
    });
  } catch (error) {
    if (timedOut) {
      throw new Error(`Web search request timed out after ${timeoutMs}ms.`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", abortFromCaller);
  }
}

// ──────────────────────────────────────────────
// Helper: format results for LLM consumption
// ──────────────────────────────────────────────

function formatExaResults(data: Record<string, unknown>): string {
  const results = data.results as Array<Record<string, unknown>> | undefined;
  if (!results || results.length === 0) {
    return "No results found.";
  }

  // If the API returned structured/synthesized output, surface it first.
  const output = data.output as
    | { content?: string | object; grounding?: Array<Record<string, unknown>> }
    | undefined;
  const parts: string[] = [];

  if (output?.content) {
    const content = typeof output.content === "string" ? output.content : JSON.stringify(output.content, null, 2);
    parts.push(`## Synthesized Answer\n${content}`);
    parts.push("");
  }

  parts.push(`## Search Results (${results.length})`);
  parts.push("");

  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    const title = r.title ?? "(no title)";
    const url = r.url ?? "";
    const date = r.publishedDate ?? "";
    const author = r.author ?? "";
    const text = r.text as string | undefined;
    const highlights = r.highlights as string[] | undefined;
    const summary = r.summary as string | undefined;

    const meta = [date, author].filter(Boolean).join(" · ");

    parts.push(`### ${i + 1}. ${title}`);
    if (url) parts.push(`**URL:** ${url}`);
    if (meta) parts.push(`**Meta:** ${meta}`);

    if (summary) {
      parts.push(`**Summary:** ${summary}`);
    }

    if (highlights && highlights.length > 0) {
      parts.push("**Highlights:**");
      for (const h of highlights.slice(0, 5)) {
        parts.push(`- ${h}`);
      }
    }

    if (text) {
      const truncated = text.length > 2000 ? text.slice(0, 2000) + "\n\n... [truncated]" : text;
      parts.push("");
      parts.push(truncated);
    }

    parts.push("");
  }

  // Include cost info if available
  if (data.costDollars) {
    const cost = data.costDollars as Record<string, number>;
    parts.push(`---`);
    parts.push(`Cost: $${cost.total?.toFixed(6) ?? "unknown"}`);
  }

  return parts.join("\n");
}

function formatTavilyResults(data: Record<string, unknown>, preferRawContent: boolean): string {
  const results = data.results as Array<Record<string, unknown>> | undefined;
  const answer = data.answer as string | undefined;
  const images = data.images as Array<string | Record<string, unknown>> | undefined;
  const query = data.query as string | undefined;

  const parts: string[] = [];

  // AI-generated answer
  if (answer) {
    parts.push(`## Answer\n${answer}`);
    parts.push("");
  }

  // Search results
  if (results && results.length > 0) {
    parts.push(`## Search Results for "${query ?? "unknown"}" (${results.length})`);
    parts.push("");

    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      const title = r.title ?? "(no title)";
      const url = r.url ?? "";
      const rawContent = typeof r.raw_content === "string" ? r.raw_content : "";
      const snippet = typeof r.content === "string" ? r.content : "";
      const content = preferRawContent ? rawContent || snippet : snippet || rawContent;
      const score = r.score as number | undefined;
      const publishedDate = r.published_date as string | undefined;
      const favicon = typeof r.favicon === "string" ? r.favicon : "";

      parts.push(`### ${i + 1}. ${title}`);
      if (url) parts.push(`**URL:** ${url}`);
      if (favicon) parts.push(`**Favicon:** ${favicon}`);
      if (score !== undefined) parts.push(`**Relevance:** ${(score * 100).toFixed(0)}%`);
      if (publishedDate) parts.push(`**Published:** ${publishedDate}`);
      if (content) {
        const truncated = content.length > 1500 ? content.slice(0, 1500) + "\n\n... [truncated]" : content;
        parts.push("");
        parts.push(truncated);
      }
      parts.push("");
    }
  } else {
    parts.push("No results found.");
  }

  // Image results can be URL strings or objects when descriptions are requested.
  if (images && images.length > 0) {
    const formattedImages = images.slice(0, 10).flatMap((image) => {
      if (typeof image === "string") return [`- ${image}`];

      const imageUrl = typeof image.url === "string" ? image.url : "";
      if (!imageUrl) return [];

      const description = typeof image.description === "string" ? image.description : "";
      return [`- ${description ? `${description}: ` : ""}${imageUrl}`];
    });

    if (formattedImages.length > 0) {
      parts.push(`## Images (${images.length})`);
      parts.push(...formattedImages, "");
    }
  }

  // Response time
  if (data.response_time) {
    parts.push(`---`);
    parts.push(`Response time: ${data.response_time}s`);
  }

  return parts.join("\n");
}

// ──────────────────────────────────────────────
// Extension
// ──────────────────────────────────────────────

export default function websearchExtension(pi: ExtensionAPI) {
  // ── Exa Search ──────────────────────────────

  pi.registerTool({
    name: "exa_search",
    label: "Exa Search",
    description:
      "Semantic web search via Exa API. Best for deep research, news retrieval, and content extraction. " +
      "Supports domain filters, date ranges, highlights, full page text extraction, and structured/synthesized output.",
    promptSnippet: "Search the web semantically with Exa and optionally extract or synthesize source content",
    parameters: Type.Object({
      query: Type.String({ description: "Natural-language search query. Long, semantically rich descriptions work well." }),
      numResults: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: 100,
          default: 10,
          description: "Number of results to return (1-100, default 10). Use small values for agent loops.",
        }),
      ),
      type: Type.Optional(
        StringEnum(["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const, {
          default: "auto",
          description:
            "Search type: auto (default), fast (low latency), instant (quickest), deep-lite, deep (multi-step research), deep-reasoning (hardest tasks).",
        }),
      ),
      highlights: Type.Optional(
        Type.Boolean({
          default: true,
          description: "Return query-relevant excerpts for each result.",
        }),
      ),
      text: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Return full page text as markdown. May increase latency.",
        }),
      ),
      maxTextCharacters: Type.Optional(
        Type.Integer({
          minimum: 1,
          description: "Character limit for returned text (requires text: true).",
        }),
      ),
      summary: Type.Optional(
        Type.Boolean({
          default: false,
          description:
            "Return per-result LLM summaries. Use sparingly as each result adds synthesis overhead.",
        }),
      ),
      category: Type.Optional(
        StringEnum(["company", "people", "research paper", "news", "personal site", "financial report"] as const, {
          description:
            "Specialized result type: company, people, research paper, news, personal site, financial report.",
        }),
      ),
      includeDomains: Type.Optional(
        Type.Array(Type.String(), {
          description: "Only return results from these domains (e.g., ['reuters.com', 'bbc.com']).",
        }),
      ),
      excludeDomains: Type.Optional(
        Type.Array(Type.String(), {
          description: "Exclude these domains from results.",
        }),
      ),
      startPublishedDate: Type.Optional(
        Type.String({
          description: "ISO 8601 lower bound for result publication date (e.g., '2025-01-01').",
        }),
      ),
      endPublishedDate: Type.Optional(
        Type.String({
          description: "ISO 8601 upper bound for result publication date.",
        }),
      ),
      maxAgeHours: Type.Optional(
        Type.Integer({
          minimum: -1,
          description:
            "Freshness control: 0 always live crawls, -1 cache only, omit for default cache-first behavior.",
        }),
      ),
      outputSchema: Type.Optional(
        Type.Record(Type.String(), Type.Any(), {
          description:
            "JSON Schema for structured/synthesized output. Only needed when structured answers are required.",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      const apiKey = getApiKey("exa");
      if (!apiKey) {
        throw missingKeyError("exa");
      }

      const body: Record<string, unknown> = {
        query: params.query,
        type: params.type ?? "auto",
        numResults: params.numResults ?? 10,
      };

      // Category
      if (params.category) body.category = params.category;

      // Domain filters
      if (params.includeDomains?.length) body.includeDomains = params.includeDomains;
      if (params.excludeDomains?.length) body.excludeDomains = params.excludeDomains;

      // Date filters
      if (params.startPublishedDate) body.startPublishedDate = params.startPublishedDate;
      if (params.endPublishedDate) body.endPublishedDate = params.endPublishedDate;

      // Contents (nested)
      const contents: Record<string, unknown> = {};

      if (params.highlights !== false) contents.highlights = true;
      if (params.text === true) {
        contents.text = params.maxTextCharacters
          ? { maxCharacters: params.maxTextCharacters }
          : true;
      }
      if (params.summary === true) contents.summary = true;
      if (params.maxAgeHours !== undefined) contents.maxAgeHours = params.maxAgeHours;

      if (Object.keys(contents).length > 0) {
        body.contents = contents;
      }

      // Structured output
      if (params.outputSchema) {
        body.outputSchema = params.outputSchema;
      }

      const response = await fetchWithTimeout("https://api.exa.ai/search", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
        },
        body: JSON.stringify(body),
        timeoutMs: 60_000,
      }, signal);

      if (!response.ok) {
        const errText = await response.text().catch(() => "unknown error");
        throw new Error(`Exa API error (${response.status}): ${errText}`);
      }

      const data = (await response.json()) as Record<string, unknown>;
      const formatted = formatExaResults(data);

      return {
        content: [{ type: "text", text: formatted }],
        details: {
          requestId: data.requestId,
          costDollars: data.costDollars,
          searchTime: data.searchTime,
          resultCount: Array.isArray(data.results) ? data.results.length : 0,
        },
      };
    },
  });

  // ── Tavily Search ───────────────────────────

  pi.registerTool({
    name: "tavily_search",
    label: "Tavily Search",
    description:
      "Web search via Tavily API. Best for quick, reliable web search with optional AI-generated answers, " +
      "domain filtering, and general, news, or finance searches. Returns ranked results with content snippets.",
    promptSnippet: "Search the web with Tavily for ranked general, news, or finance results and optional answers",
    parameters: Type.Object({
      query: Type.String({ description: "Search query string." }),
      maxResults: Type.Optional(
        Type.Integer({
          minimum: 0,
          maximum: 20,
          default: 10,
          description: "Number of results to return (0-20, default 10).",
        }),
      ),
      searchDepth: Type.Optional(
        StringEnum(["basic", "advanced", "fast", "ultra-fast"] as const, {
          default: "basic",
          description:
            "Search depth: basic, advanced, fast, or ultra-fast. Advanced enables deeper retrieval.",
        }),
      ),
      topic: Type.Optional(
        StringEnum(["general", "news", "finance"] as const, {
          default: "general",
          description: "Search topic: general, news, or finance.",
        }),
      ),
      days: Type.Optional(
        Type.Integer({
          minimum: 1,
          description:
            "Only return results published within this many days. Primarily used with topic: news.",
        }),
      ),
      timeRange: Type.Optional(
        StringEnum(["day", "week", "month", "year", "d", "w", "m", "y"] as const, {
          description: "Relative publication time range, using a full name or d/w/m/y shorthand.",
        }),
      ),
      startDate: Type.Optional(
        Type.String({
          pattern: "^\\d{4}-\\d{2}-\\d{2}$",
          description: "Earliest publication date in YYYY-MM-DD format.",
        }),
      ),
      endDate: Type.Optional(
        Type.String({
          pattern: "^\\d{4}-\\d{2}-\\d{2}$",
          description: "Latest publication date in YYYY-MM-DD format.",
        }),
      ),
      chunksPerSource: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: 3,
          description: "Relevant chunks to return per source (1-3, only with advanced search).",
        }),
      ),
      includeAnswer: Type.Optional(
        Type.Boolean({
          default: true,
          description: "Include an AI-generated answer. Set false to disable it.",
        }),
      ),
      answerDepth: Type.Optional(
        StringEnum(["basic", "advanced"] as const, {
          description: "Generated-answer depth. Applies when includeAnswer is not false.",
        }),
      ),
      includeRawContent: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Include cleaned page content for each result. Set false to disable it.",
        }),
      ),
      rawContentFormat: Type.Optional(
        StringEnum(["markdown", "text"] as const, {
          description: "Raw-content format. Supplying this also enables raw content unless includeRawContent is false.",
        }),
      ),
      includeImages: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Include image results.",
        }),
      ),
      includeImageDescriptions: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Include a description with each image result.",
        }),
      ),
      includeFavicon: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Include the favicon URL for each result.",
        }),
      ),
      includeDomains: Type.Optional(
        Type.Array(Type.String(), {
          maxItems: 300,
          description: "Only return results from these domains (maximum 300).",
        }),
      ),
      excludeDomains: Type.Optional(
        Type.Array(Type.String(), {
          maxItems: 150,
          description: "Exclude these domains from results (maximum 150).",
        }),
      ),
      country: Type.Optional(
        Type.String({
          description: "Country name whose sources should be boosted. Available only with topic: general.",
        }),
      ),
      autoParameters: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Let Tavily tune search parameters from the query. May select advanced depth at extra cost.",
        }),
      ),
      exactMatch: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Require quoted phrases in the query to match exactly.",
        }),
      ),
      includeUsage: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Include API credit usage in the response metadata.",
        }),
      ),
      safeSearch: Type.Optional(
        Type.Boolean({
          default: false,
          description: "Filter adult or unsafe results. Enterprise only; unsupported by fast depths.",
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      const apiKey = getApiKey("tavily");
      if (!apiKey) {
        throw missingKeyError("tavily");
      }

      const includeAnswer = params.includeAnswer === false
        ? false
        : params.answerDepth ?? params.includeAnswer ?? true;
      const includeRawContent = params.includeRawContent === false
        ? false
        : params.rawContentFormat ?? params.includeRawContent ?? false;

      const body: Record<string, unknown> = {
        query: params.query,
        max_results: params.maxResults ?? 10,
        search_depth: params.searchDepth ?? "basic",
        topic: params.topic ?? "general",
        include_answer: includeAnswer,
        include_raw_content: includeRawContent,
        include_images: params.includeImages ?? false,
        include_image_descriptions: params.includeImageDescriptions ?? false,
        include_favicon: params.includeFavicon ?? false,
        auto_parameters: params.autoParameters ?? false,
        exact_match: params.exactMatch ?? false,
        include_usage: params.includeUsage ?? false,
        safe_search: params.safeSearch ?? false,
      };

      if (params.days !== undefined) body.days = params.days;
      if (params.timeRange) body.time_range = params.timeRange;
      if (params.startDate) body.start_date = params.startDate;
      if (params.endDate) body.end_date = params.endDate;
      if (params.chunksPerSource !== undefined) body.chunks_per_source = params.chunksPerSource;
      if (params.includeDomains?.length) body.include_domains = params.includeDomains;
      if (params.excludeDomains?.length) body.exclude_domains = params.excludeDomains;
      if (params.country) body.country = params.country;

      const response = await fetchWithTimeout("https://api.tavily.com/search", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        timeoutMs: 60_000,
      }, signal);

      if (!response.ok) {
        const errText = await response.text().catch(() => "unknown error");
        throw new Error(`Tavily API error (${response.status}): ${errText}`);
      }

      const data = (await response.json()) as Record<string, unknown>;
      const formatted = formatTavilyResults(data, includeRawContent !== false);

      return {
        content: [{ type: "text", text: formatted }],
        details: {
          query: data.query,
          responseTime: data.response_time,
          resultCount: Array.isArray(data.results) ? data.results.length : 0,
          imageCount: Array.isArray(data.images) ? data.images.length : 0,
          usage: data.usage,
        },
      };
    },
  });

}
