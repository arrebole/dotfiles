import type { Static } from "typebox";
import { Type } from "typebox";
import { getApiKey, missingKeyError } from "../config";
import { formatTavilyResults } from "../formatters";
import { fetchWithTimeout } from "../http";

export const tavilyParameters = Type.Object({
  query: Type.String(),
  maxResults: Type.Optional(Type.Integer({ minimum: 0, maximum: 20, default: 10 })),
  searchDepth: Type.Optional(Type.Union([
    Type.Literal("basic"), Type.Literal("advanced"), Type.Literal("fast"), Type.Literal("ultra-fast"),
  ])),
  topic: Type.Optional(Type.Union([Type.Literal("general"), Type.Literal("news"), Type.Literal("finance")])),
  days: Type.Optional(Type.Integer({ minimum: 1 })),
  timeRange: Type.Optional(Type.Union([
    Type.Literal("day"), Type.Literal("week"), Type.Literal("month"), Type.Literal("year"),
    Type.Literal("d"), Type.Literal("w"), Type.Literal("m"), Type.Literal("y"),
  ])),
  startDate: Type.Optional(Type.String({ pattern: "^\\d{4}-\\d{2}-\\d{2}$" })),
  endDate: Type.Optional(Type.String({ pattern: "^\\d{4}-\\d{2}-\\d{2}$" })),
  chunksPerSource: Type.Optional(Type.Integer({ minimum: 1, maximum: 3 })),
  includeAnswer: Type.Optional(Type.Boolean()),
  answerDepth: Type.Optional(Type.Union([Type.Literal("basic"), Type.Literal("advanced")])),
  includeRawContent: Type.Optional(Type.Boolean()),
  rawContentFormat: Type.Optional(Type.Union([Type.Literal("markdown"), Type.Literal("text")])),
  includeImages: Type.Optional(Type.Boolean()),
  includeImageDescriptions: Type.Optional(Type.Boolean()),
  includeFavicon: Type.Optional(Type.Boolean()),
  includeDomains: Type.Optional(Type.Array(Type.String(), { maxItems: 300 })),
  excludeDomains: Type.Optional(Type.Array(Type.String(), { maxItems: 150 })),
  country: Type.Optional(Type.String()),
  autoParameters: Type.Optional(Type.Boolean()),
  exactMatch: Type.Optional(Type.Boolean()),
  includeUsage: Type.Optional(Type.Boolean()),
  safeSearch: Type.Optional(Type.Boolean()),
});

export type TavilySearchParams = Static<typeof tavilyParameters>;

export async function executeTavilySearch(params: TavilySearchParams, signal?: AbortSignal) {
  const apiKey = getApiKey("tavily");
  if (!apiKey) throw missingKeyError("tavily");

  const includeAnswer = params.includeAnswer === false ? false : params.answerDepth ?? params.includeAnswer ?? true;
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
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
    timeoutMs: 60_000,
  }, signal);
  if (!response.ok) {
    const errText = await response.text().catch(() => "unknown error");
    throw new Error(`Tavily API error (${response.status}): ${errText}`);
  }

  const data = (await response.json()) as Record<string, unknown>;
  return {
    content: [{ type: "text" as const, text: formatTavilyResults(data, includeRawContent !== false) }],
    details: {
      provider: "tavily",
      query: data.query,
      responseTime: data.response_time,
      resultCount: Array.isArray(data.results) ? data.results.length : 0,
      imageCount: Array.isArray(data.images) ? data.images.length : 0,
      usage: data.usage,
    },
  };
}
