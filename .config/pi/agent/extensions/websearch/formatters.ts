export function formatExaResults(data: Record<string, unknown>): string {
  const results = data.results as Array<Record<string, unknown>> | undefined;
  if (!results || results.length === 0) return "No results found.";

  const output = data.output as
    | { content?: string | object; grounding?: Array<Record<string, unknown>> }
    | undefined;
  const parts: string[] = [];

  if (output?.content) {
    const content = typeof output.content === "string" ? output.content : JSON.stringify(output.content, null, 2);
    parts.push(`## Synthesized Answer\n${content}`, "");
  }

  parts.push(`## Search Results (${results.length})`, "");
  for (let i = 0; i < results.length; i++) {
    const result = results[i];
    const title = result.title ?? "(no title)";
    const url = result.url ?? "";
    const date = result.publishedDate ?? "";
    const author = result.author ?? "";
    const text = result.text as string | undefined;
    const highlights = result.highlights as string[] | undefined;
    const summary = result.summary as string | undefined;
    const meta = [date, author].filter(Boolean).join(" · ");

    parts.push(`### ${i + 1}. ${title}`);
    if (url) parts.push(`**URL:** ${url}`);
    if (meta) parts.push(`**Meta:** ${meta}`);
    if (summary) parts.push(`**Summary:** ${summary}`);
    if (highlights?.length) {
      parts.push("**Highlights:**");
      for (const highlight of highlights.slice(0, 5)) parts.push(`- ${highlight}`);
    }
    if (text) {
      parts.push("", text.length > 2000 ? `${text.slice(0, 2000)}\n\n... [truncated]` : text);
    }
    parts.push("");
  }

  if (data.costDollars) {
    const cost = data.costDollars as Record<string, number>;
    parts.push("---", `Cost: $${cost.total?.toFixed(6) ?? "unknown"}`);
  }

  return parts.join("\n");
}

export function formatTavilyResults(data: Record<string, unknown>, preferRawContent: boolean): string {
  const results = data.results as Array<Record<string, unknown>> | undefined;
  const answer = data.answer as string | undefined;
  const images = data.images as Array<string | Record<string, unknown>> | undefined;
  const query = data.query as string | undefined;
  const parts: string[] = [];

  if (answer) parts.push(`## Answer\n${answer}`, "");
  if (results?.length) {
    parts.push(`## Search Results for "${query ?? "unknown"}" (${results.length})`, "");
    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      const title = result.title ?? "(no title)";
      const url = result.url ?? "";
      const rawContent = typeof result.raw_content === "string" ? result.raw_content : "";
      const snippet = typeof result.content === "string" ? result.content : "";
      const content = preferRawContent ? rawContent || snippet : snippet || rawContent;
      const score = result.score as number | undefined;
      const publishedDate = result.published_date as string | undefined;
      const favicon = typeof result.favicon === "string" ? result.favicon : "";

      parts.push(`### ${i + 1}. ${title}`);
      if (url) parts.push(`**URL:** ${url}`);
      if (favicon) parts.push(`**Favicon:** ${favicon}`);
      if (score !== undefined) parts.push(`**Relevance:** ${(score * 100).toFixed(0)}%`);
      if (publishedDate) parts.push(`**Published:** ${publishedDate}`);
      if (content) parts.push("", content.length > 1500 ? `${content.slice(0, 1500)}\n\n... [truncated]` : content);
      parts.push("");
    }
  } else {
    parts.push("No results found.");
  }

  if (images?.length) {
    const formattedImages = images.slice(0, 10).flatMap((image) => {
      if (typeof image === "string") return [`- ${image}`];
      const imageUrl = typeof image.url === "string" ? image.url : "";
      if (!imageUrl) return [];
      const description = typeof image.description === "string" ? image.description : "";
      return [`- ${description ? `${description}: ` : ""}${imageUrl}`];
    });
    if (formattedImages.length) parts.push(`## Images (${images.length})`, ...formattedImages, "");
  }

  if (data.response_time) parts.push("---", `Response time: ${data.response_time}s`);
  return parts.join("\n");
}
