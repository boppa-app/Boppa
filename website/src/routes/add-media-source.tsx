import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { createIsomorphicFn } from "@tanstack/react-start";
import { getRequestHeader } from "@tanstack/react-start/server";
import { useState } from "react";
import { SiteShell } from "~/components/site-shell";
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
  validateSearch: (search: Record<string, unknown>): { url?: string } => ({
    url: typeof search.url === "string" ? search.url : undefined,
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
  const { url } = Route.useSearch();
  const { platform } = Route.useLoaderData();

  return (
    <SiteShell>
      <h1 className="text-3xl md:text-4xl font-semibold tracking-tight mb-2">
        Add Media Source
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
    new URL(value);
    return true;
  } catch {
    return false;
  }
}

function withScheme(value: string): string {
  return /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(value) ? value : `https://${value}`;
}

function GenerateLinkForm() {
  const navigate = useNavigate({ from: Route.fullPath });
  const [configUrl, setConfigUrl] = useState("");
  const [invalid, setInvalid] = useState(false);

  return (
    <form
      className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        const trimmed = configUrl.trim();
        if (!trimmed) return;
        const withUrlScheme = withScheme(trimmed);
        if (!isValidUrl(withUrlScheme)) {
          setInvalid(true);
          return;
        }
        navigate({ search: { url: withUrlScheme } });
      }}
    >
      <label htmlFor="config-url" className="block text-sm text-muted-foreground">
        Paste a media source config URL to generate a link that adds it to
        Boppa.
      </label>
      <input
        id="config-url"
        type="text"
        inputMode="url"
        autoCapitalize="none"
        autoCorrect="off"
        placeholder="https://data.boppa.app/iOS/internet-archive.yaml"
        value={configUrl}
        onChange={(event) => {
          setConfigUrl(event.target.value);
          setInvalid(false);
        }}
        aria-invalid={invalid}
        className={`w-full rounded-lg border bg-background px-4 py-3 text-sm text-foreground focus:outline-none focus:ring-2 ${
          invalid
            ? "border-red-500 focus:ring-red-500"
            : "border-border focus:ring-primary"
        }`}
      />
      {invalid && (
        <p className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          Please enter a valid URL.
        </p>
      )}
      <button
        type="submit"
        disabled={!configUrl.trim()}
        className="inline-flex items-center justify-center rounded-lg border-2 border-foreground/20 px-4 py-2 text-sm font-medium text-foreground hover:bg-foreground/10 transition-colors disabled:opacity-50 disabled:pointer-events-none"
      >
        Generate Link
      </button>
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
        className="inline-flex items-center justify-center rounded-lg border-2 border-foreground/20 px-4 py-2 text-sm font-medium text-foreground hover:bg-foreground/10 transition-colors"
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
  return (
    <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 space-y-4">
      <p className="text-sm text-muted-foreground">
        The Boppa Android app isn&apos;t out yet, so this link can&apos;t open
        it directly. Check back once it&apos;s available.
      </p>
      <Link
        to="/download"
        className="inline-flex items-center justify-center rounded-lg border-2 border-foreground/20 px-4 py-2 text-sm font-medium text-foreground hover:bg-foreground/10 transition-colors"
      >
        See download status
      </Link>
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
            setTimeout(() => setCopied(false), 2000);
          }}
          className="inline-flex items-center justify-center rounded-lg border-2 border-foreground/20 px-4 py-2 text-sm font-medium text-foreground hover:bg-foreground/10 transition-colors"
        >
          {copied ? "Copied!" : "Copy link"}
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
