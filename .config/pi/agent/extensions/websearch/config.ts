export type SearchProvider = "exa" | "tavily";

const API_KEY_ENV: Record<SearchProvider, "EXA_API_KEY" | "TAVILY_API_KEY"> = {
  exa: "EXA_API_KEY",
  tavily: "TAVILY_API_KEY",
};

// Optional: paste API keys here if you do not want to use environment variables.
const MANUAL_API_KEYS: Record<SearchProvider, string> = {
  exa: "",
  tavily: "",
};

export function getApiKey(provider: SearchProvider): string | undefined {
  return process.env[API_KEY_ENV[provider]]?.trim() || MANUAL_API_KEYS[provider].trim() || undefined;
}

export function missingKeyError(provider: SearchProvider): Error {
  const envName = API_KEY_ENV[provider];
  return new Error(
    `${envName} is not set. Set the environment variable or paste the ${provider} key into MANUAL_API_KEYS in config.ts.`,
  );
}
