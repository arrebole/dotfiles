import type { Static } from "typebox";
import { Type } from "typebox";
import { getApiKey, missingKeyError } from "../config";
import { formatExaResults } from "../formatters";
import { fetchWithTimeout } from "../http";

export const exaParameters = Type.Object({
  query: Type.String(),
  numResults: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 10 })),
  type: Type.Optional(Type.Union([
    Type.Literal("auto"), Type.Literal("fast"), Type.Literal("instant"),
    Type.Literal("deep-lite"), Type.Literal("deep"), Type.Literal("deep-reasoning"),
  ])),
  highlights: Type.Optional(Type.Boolean()),
  text: Type.Optional(Type.Boolean()),
  maxTextCharacters: Type.Optional(Type.Integer({ minimum: 1 })),
  summary: Type.Optional(Type.Boolean()),
  category: Type.Optional(Type.Union([
    Type.Literal("company"), Type.Literal("people"), Type.Literal("research paper"),
    Type.Literal("news"), Type.Literal("personal site"), Type.Literal("financial report"),
  ])),
  includeDomains: Type.Optional(Type.Array(Type.String())),
  excludeDomains: Type.Optional(Type.Array(Type.String())),
  startPublishedDate: Type.Optional(Type.String()),
  endPublishedDate: Type.Optional(Type.String()),
  maxAgeHours: Type.Optional(Type.Integer({ minimum: -1 })),
  outputSchema: Type.Optional(Type.Record(Type.String(), Type.Any())),
});

export type ExaSearchParams = Static<typeof exaParameters>;

export async function executeExaSearch(params: ExaSearchParams, signal?: AbortSignal) {
  const apiKey = getApiKey("exa");
  if (!apiKey) throw missingKeyError("exa");

  const body: Record<string, unknown> = {
    query: params.query,
    type: params.type ?? "auto",
    numResults: params.numResults ?? 10,
  };
  if (params.category) body.category = params.category;
  if (params.includeDomains?.length) body.includeDomains = params.includeDomains;
  if (params.excludeDomains?.length) body.excludeDomains = params.excludeDomains;
  if (params.startPublishedDate) body.startPublishedDate = params.startPublishedDate;
  if (params.endPublishedDate) body.endPublishedDate = params.endPublishedDate;

  const contents: Record<string, unknown> = {};
  if (params.highlights !== false) contents.highlights = true;
  if (params.text === true) {
    contents.text = params.maxTextCharacters ? { maxCharacters: params.maxTextCharacters } : true;
  }
  if (params.summary === true) contents.summary = true;
  if (params.maxAgeHours !== undefined) contents.maxAgeHours = params.maxAgeHours;
  if (Object.keys(contents).length) body.contents = contents;
  if (params.outputSchema) body.outputSchema = params.outputSchema;

  const response = await fetchWithTimeout("https://api.exa.ai/search", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-api-key": apiKey },
    body: JSON.stringify(body),
    timeoutMs: 60_000,
  }, signal);
  if (!response.ok) {
    const errText = await response.text().catch(() => "unknown error");
    throw new Error(`Exa API error (${response.status}): ${errText}`);
  }

  const data = (await response.json()) as Record<string, unknown>;
  return {
    content: [{ type: "text" as const, text: formatExaResults(data) }],
    details: {
      provider: "exa",
      requestId: data.requestId,
      costDollars: data.costDollars,
      searchTime: data.searchTime,
      resultCount: Array.isArray(data.results) ? data.results.length : 0,
    },
  };
}
