/**
 * WebSearch Extension
 *
 * Exposes one websearch tool. Common parameters live at the top level; each
 * provider's advanced options live under `options`. Requests are dispatched to
 * Exa or Tavily based on the provider parameter. API keys live in config.ts.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";
import { executeExaSearch } from "./providers/exa";
import { executeTavilySearch } from "./providers/tavily";

// Provider-specific advanced options. Common options (result count, domain
// filters, date range) are promoted to the top level and mapped per provider.
const options = Type.Object(
  {
    // ── Exa advanced options ──────────────────
    type: Type.Optional(StringEnum(["auto", "fast", "instant", "deep-lite", "deep", "deep-reasoning"] as const, { default: "auto", description: "[Exa] Search mode. Use deep or deep-reasoning for multi-step research." })),
    highlights: Type.Optional(Type.Boolean({ default: true, description: "[Exa] Return query-relevant excerpts per result." })),
    text: Type.Optional(Type.Boolean({ default: false, description: "[Exa] Return full page text as markdown (higher latency)." })),
    maxTextCharacters: Type.Optional(Type.Integer({ minimum: 1, description: "[Exa] Max characters per full-text result; requires text=true." })),
    summary: Type.Optional(Type.Boolean({ default: false, description: "[Exa] Generate an LLM summary per result." })),
    category: Type.Optional(StringEnum(["company", "people", "research paper", "news", "personal site", "financial report"] as const, { description: "[Exa] Restrict results to a specialized category." })),
    maxAgeHours: Type.Optional(Type.Integer({ minimum: -1, description: "[Exa] Freshness: 0 forces live crawl, -1 cache only." })),
    outputSchema: Type.Optional(Type.Record(Type.String(), Type.Any(), { description: "[Exa] JSON Schema for structured/synthesized output." })),

    // ── Tavily advanced options ───────────────
    searchDepth: Type.Optional(StringEnum(["basic", "advanced", "fast", "ultra-fast"] as const, { default: "basic", description: "[Tavily] Search depth / latency mode; advanced enables deeper retrieval." })),
    topic: Type.Optional(StringEnum(["general", "news", "finance"] as const, { default: "general", description: "[Tavily] Search topic. Use news for recency, finance for markets." })),
    days: Type.Optional(Type.Integer({ minimum: 1, description: "[Tavily] Limit results to the last N days (mainly for topic=news)." })),
    timeRange: Type.Optional(StringEnum(["day", "week", "month", "year", "d", "w", "m", "y"] as const, { description: "[Tavily] Relative publication time range." })),
    chunksPerSource: Type.Optional(Type.Integer({ minimum: 1, maximum: 3, description: "[Tavily] Relevant chunks per source (advanced depth only)." })),
    includeAnswer: Type.Optional(Type.Boolean({ default: true, description: "[Tavily] Include an AI-generated answer." })),
    answerDepth: Type.Optional(StringEnum(["basic", "advanced"] as const, { description: "[Tavily] Generated-answer depth." })),
    includeRawContent: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Include cleaned full page content per result." })),
    rawContentFormat: Type.Optional(StringEnum(["markdown", "text"] as const, { description: "[Tavily] Raw-content format." })),
    includeImages: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Include image results." })),
    includeImageDescriptions: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Add descriptions to image results." })),
    includeFavicon: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Include favicon URLs." })),
    country: Type.Optional(Type.String({ description: "[Tavily] Boost sources from this country (topic=general only)." })),
    autoParameters: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Let Tavily auto-tune parameters from the query." })),
    exactMatch: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Require quoted phrases to match exactly." })),
    includeUsage: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Include API credit usage metadata." })),
    safeSearch: Type.Optional(Type.Boolean({ default: false, description: "[Tavily] Enable enterprise safe-search filtering." })),
  },
  {
    description:
      "Provider-specific advanced options. [Exa]: type, highlights, text, maxTextCharacters, summary, category, maxAgeHours, outputSchema (semantic depth, content extraction, structured output). " +
      "[Tavily]: searchDepth, topic, days, timeRange, chunksPerSource, includeAnswer, answerDepth, includeRawContent, rawContentFormat, includeImages, includeImageDescriptions, includeFavicon, country, autoParameters, exactMatch, includeUsage, safeSearch (news/finance topics, generated answers, images). " +
      "Options for the non-selected provider are ignored.",
  },
);

export default function websearchExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "websearch",
    label: "Web Search",
    description:
      "Search the web through a selected provider. Choose Exa for semantic search, deep research, " +
      "high-quality highlights, full-page extraction, and structured output. Choose Tavily for fast " +
      "ranked results, current news or finance searches, generated answers, and images. " +
      "Common options are top-level; provider-specific advanced options go in `options`.",
    promptSnippet: "Search the web with Exa (semantic/deep research) or Tavily (fast news/finance/answers)",
    parameters: Type.Object({
      provider: StringEnum(["exa", "tavily"] as const, {
        description:
          "Search provider. exa: semantic/deep research, content extraction, structured output. tavily: fast general/news/finance lookup with generated answers.",
      }),
      query: Type.String({ description: "Search query string." }),
      numResults: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 10, description: "Number of results (default 10). Exa allows up to 100; Tavily caps at 20." })),
      includeDomains: Type.Optional(Type.Array(Type.String(), { description: "Only return results from these domains." })),
      excludeDomains: Type.Optional(Type.Array(Type.String(), { description: "Exclude results from these domains." })),
      startDate: Type.Optional(Type.String({ description: "Earliest publication date. Exa accepts ISO 8601; Tavily requires YYYY-MM-DD." })),
      endDate: Type.Optional(Type.String({ description: "Latest publication date. Exa accepts ISO 8601; Tavily requires YYYY-MM-DD." })),
      options: Type.Optional(options),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      const { provider, query, numResults, includeDomains, excludeDomains, startDate, endDate } = params;
      const opts = params.options ?? {};

      if (provider === "exa") {
        return executeExaSearch({
          query,
          numResults,
          includeDomains,
          excludeDomains,
          startPublishedDate: startDate,
          endPublishedDate: endDate,
          type: opts.type,
          highlights: opts.highlights,
          text: opts.text,
          maxTextCharacters: opts.maxTextCharacters,
          summary: opts.summary,
          category: opts.category,
          maxAgeHours: opts.maxAgeHours,
          outputSchema: opts.outputSchema,
        }, signal);
      }

      return executeTavilySearch({
        query,
        maxResults: numResults !== undefined ? Math.min(numResults, 20) : undefined,
        includeDomains,
        excludeDomains,
        startDate,
        endDate,
        searchDepth: opts.searchDepth,
        topic: opts.topic,
        days: opts.days,
        timeRange: opts.timeRange,
        chunksPerSource: opts.chunksPerSource,
        includeAnswer: opts.includeAnswer,
        answerDepth: opts.answerDepth,
        includeRawContent: opts.includeRawContent,
        rawContentFormat: opts.rawContentFormat,
        includeImages: opts.includeImages,
        includeImageDescriptions: opts.includeImageDescriptions,
        includeFavicon: opts.includeFavicon,
        country: opts.country,
        autoParameters: opts.autoParameters,
        exactMatch: opts.exactMatch,
        includeUsage: opts.includeUsage,
        safeSearch: opts.safeSearch,
      }, signal);
    },
  });
}
