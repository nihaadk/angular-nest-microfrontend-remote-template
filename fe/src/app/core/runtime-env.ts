/**
 * Runtime config for this remote, loaded from /env.json before Angular
 * bootstraps (see main.ts). This lets a container built once know where its
 * backend lives, set via a Railway variable and written into env.json by
 * the Docker entrypoint at container start - no rebuild needed.
 *
 * Falls back to same-origin ('') if env.json is missing or invalid.
 */
export interface RuntimeEnv {
  /** Base URL of this remote's backend API, e.g. 'https://my-remote-be.up.railway.app'. Empty string means same-origin. */
  beUrl: string;
}

declare global {
  interface Window {
    __env__?: RuntimeEnv;
  }
}

const FALLBACK_ENV: RuntimeEnv = { beUrl: '' };

export async function loadRuntimeEnv(): Promise<RuntimeEnv> {
  try {
    const response = await fetch('/env.json');
    if (!response.ok) {
      throw new Error(`Unexpected status ${response.status}`);
    }
    const env = (await response.json()) as Partial<RuntimeEnv>;
    return { beUrl: env.beUrl ?? '' };
  } catch (err) {
    console.error('Could not load /env.json, falling back to same-origin API calls.', err);
    return FALLBACK_ENV;
  }
}

/** Reads the runtime env stashed on `window` by main.ts. Safe to call anytime after bootstrap. */
export function getRuntimeEnv(): RuntimeEnv {
  return window.__env__ ?? FALLBACK_ENV;
}
