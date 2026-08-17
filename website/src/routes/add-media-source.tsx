import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { createIsomorphicFn } from "@tanstack/react-start";
import { getRequestHeader } from "@tanstack/react-start/server";
import { useRef, useState } from "react";
import { AlertCircle, CornerDownLeft, Loader2 } from "lucide-react";
import { load as loadYaml } from "js-yaml";
import { SiteShell } from "~/components/site-shell";
import { WaitlistForm } from "~/components/waitlist-form";
import { pageMeta } from "~/meta";

type Platform = "ios" | "android" | "other";

function platformFromUserAgent(userAgent: string | undefined): Platform {
  const ua = userAgent ?? "";
  if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
  if (/Android/i.test(ua)) return "android";
  return "other";
}

const detectPlatform = createIsomorphicFn()
  .server(() => platformFromUserAgent(getRequestHeader("user-agent")))
  .client(() => platformFromUserAgent(navigator.userAgent));

export const Route = createFileRoute("/add-media-source")({
  validateSearch: (search: Record<string, unknown>): { url?: string; name?: string } => ({
    url: typeof search.url === "string" ? search.url : undefined,
    name: typeof search.name === "string" ? search.name : undefined,
  }),
  loader: () => ({
    platform: detectPlatform(),
  }),
  head: () =>
    pageMeta(
      "Add Media Source - Boppa",
      "Add a media source to Boppa.",
      "/add-media-source",
    ),
  component: AddSource,
});

function AddSource() {
  const { url, name } = Route.useSearch();
  const { platform } = Route.useLoaderData();

  return (
    <SiteShell>
      <h1 className="text-3xl md:text-4xl font-semibold tracking-tight mb-2">
        {url ? (name ? `Add "${name}" Media Source?` : "Add Media Source?") : "Add Media Source"}
      </h1>

      {!url ? (
        <div className="mt-10">
          <GenerateLinkForm />
        </div>
      ) : (
        <>
          <p className="text-muted-foreground mb-10 break-all">{url}</p>
          {platform === "ios" && <IosPrompt url={url} />}
          {platform === "android" && <AndroidPrompt />}
          {platform === "other" && <DesktopPrompt url={url} />}
        </>
      )}
    </SiteShell>
  );
}

function isValidUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.hostname === "localhost" || url.hostname.includes(".");
  } catch {
    return false;
  }
}

function withScheme(value: string): string {
  return /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(value) ? value : `https://${value}`;
}

async function validateConfigUrl(
  rawUrl: string,
): Promise<{ ok: true; url: string; name?: string } | { ok: false; message: string }> {
  const withUrlScheme = withScheme(rawUrl);
  if (!isValidUrl(withUrlScheme)) {
    return { ok: false, message: "Please enter a valid URL." };
  }
  if (!new URL(withUrlScheme).pathname.toLowerCase().endsWith(".yaml")) {
    return { ok: false, message: "The URL must point to a .yaml file." };
  }

  let response: Response;
  try {
    response = await fetch(withUrlScheme);
  } catch {
    return { ok: false, message: "Couldn't download this file. Make sure the URL is publicly accessible." };
  }
  if (!response.ok) {
    return { ok: false, message: "Couldn't download this file. Make sure the URL is publicly accessible." };
  }

  const text = await response.text();
  let parsed: unknown;
  try {
    parsed = loadYaml(text);
  } catch {
    return { ok: false, message: "This file isn't valid YAML." };
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed) || !("name" in parsed)) {
    return { ok: false, message: "This YAML file is missing a top-level name key." };
  }

  const name = (parsed as Record<string, unknown>).name;
  return { ok: true, url: withUrlScheme, name: typeof name === "string" ? name : undefined };
}

function GenerateLinkForm() {
  const navigate = useNavigate({ from: Route.fullPath });
  const [configUrl, setConfigUrl] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "invalid">("idle");
  const [errorMessage, setErrorMessage] = useState("");
  const formRef = useRef<HTMLFormElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const isInvalid = status === "invalid";

  return (
    <form
      ref={formRef}
      className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4"
      noValidate
      onSubmit={async (event) => {
        event.preventDefault();
        const trimmed = configUrl.trim();
        if (!trimmed) return;
        setStatus("loading");
        const result = await validateConfigUrl(trimmed);
        if (!result.ok) {
          setErrorMessage(result.message);
          setStatus("invalid");
          return;
        }
        navigate({ search: { url: result.url, name: result.name } });
      }}
    >
      <label
        htmlFor="config-url"
        className="block text-sm text-muted-foreground"
        onMouseDown={(event) => {
          event.preventDefault();
          if (document.activeElement === inputRef.current) {
            inputRef.current?.blur();
          }
        }}
        onClick={(event) => event.preventDefault()}
      >
        Paste a media source config URL to generate a link that adds it to
        Boppa.
      </label>
      <div className="relative flex items-center">
        <input
          ref={inputRef}
          id="config-url"
          type="text"
          inputMode="url"
          autoCapitalize="none"
          autoCorrect="off"
          placeholder="https://data.boppa.app/iOS/internet-archive.yaml"
          value={configUrl}
          onChange={(event) => {
            setConfigUrl(event.target.value);
            if (isInvalid) setStatus("idle");
          }}
          aria-invalid={isInvalid}
          disabled={status === "loading"}
          className={`w-full rounded-lg border bg-background px-4 py-3 pr-12 text-base sm:text-sm text-foreground focus:outline-none disabled:opacity-50 ${
            isInvalid
              ? "border-red-500"
              : "border-border focus:border-primary"
          }`}
        />
        {isInvalid ? (
          <AlertCircle className="absolute right-3 w-4 h-4 text-red-500 pointer-events-none" />
        ) : (
          <button
            type="submit"
            aria-label="Generate link"
            disabled={!configUrl.trim() || status === "loading"}
            className="absolute right-3 text-muted-foreground hover:text-foreground transition-colors disabled:opacity-50 disabled:pointer-events-none"
          >
            {status === "loading" ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <CornerDownLeft className="w-4 h-4" />
            )}
          </button>
        )}
      </div>
      {isInvalid && <p className="text-sm text-red-400">{errorMessage}</p>}
    </form>
  );
}

function IosPrompt({ url }: { url: string }) {
  const appLinkUrl = `boppa://add-media-source?url=${encodeURIComponent(url)}`;

  return (
    <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4">
      <p className="text-sm text-muted-foreground">
        Open this link in Boppa to add this media source.
      </p>
      <a
        href={appLinkUrl}
        className="inline-flex items-center justify-center cursor-pointer rounded-lg border-2 border-primary bg-primary/10 px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-primary/30"
      >
        Open in Boppa
      </a>
      <p className="text-sm text-muted-foreground">
        Don&apos;t have the app yet?{" "}
        <Link to="/download" className="text-foreground underline underline-offset-2">
          Download Boppa
        </Link>
      </p>
    </section>
  );
}

function AndroidPrompt() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4">
      <p className="text-sm text-muted-foreground">
        The Boppa Android app isn&apos;t out yet, so this link can&apos;t open
        it directly.
      </p>
      <WaitlistForm platform="android" isOpen={isOpen} onOpen={() => setIsOpen(true)} />
    </section>
  );
}

function DesktopPrompt({ url }: { url: string }) {
  const [copied, setCopied] = useState(false);
  const canonicalUrl = `https://boppa.app/add-media-source?url=${encodeURIComponent(url)}`;

  return (
    <>
      <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4">
        <p className="text-sm text-muted-foreground">
          This link is meant to be opened on your phone. Copy it and open it
          there.
        </p>
        <button
          type="button"
          onClick={() => {
            navigator.clipboard.writeText(canonicalUrl);
            setCopied(true);
            setTimeout(() => setCopied(false), 1000);
          }}
          className="inline-flex items-center justify-center cursor-pointer rounded-lg border-2 border-primary bg-primary/10 px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-primary/30"
        >
          {copied ? "Copied!" : "Copy Link"}
        </button>
      </section>
      <Link
        to="/add-media-source"
        className="inline-flex mt-10 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
      >
        Generate new link
      </Link>
    </>
  );
}
