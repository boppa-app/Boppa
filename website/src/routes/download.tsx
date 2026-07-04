import { createFileRoute } from "@tanstack/react-router";
import { SiteShell } from "~/components/site-shell";
import { pageMeta } from "~/meta";

export const Route = createFileRoute("/download")({
  head: () =>
    pageMeta(
      "Download Boppa",
      "Download Boppa for Mobile and Desktop.",
      "/download",
    ),
  component: Download,
});

function StatusPill({ label }: { label: string }) {
  return (
    <span className="inline-flex items-center justify-center rounded-full border border-border px-4 py-1.5 text-sm font-medium text-muted-foreground">
      {label}
    </span>
  );
}

function PlatformRow({ name, status }: { name: string; status: string }) {
  return (
    <div className="flex flex-col gap-3 py-5 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between">
      <span className="font-medium">{name}</span>
      <StatusPill label={status} />
    </div>
  );
}

function Download() {
  return (
    <SiteShell>
      <h1 className="text-3xl md:text-4xl font-semibold tracking-tight mb-2">
        Download
      </h1>
      <p className="text-muted-foreground mb-10">
        Boppa is still in development.
      </p>

      <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 mb-6">
        <h2 className="text-2xl font-semibold mb-8">Mobile</h2>
        <div className="divide-y divide-border">
          <PlatformRow name="iOS" status="Coming soon..." />
          <PlatformRow name="Android" status="Coming eventually" />
        </div>
      </section>

      <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8">
        <h2 className="text-2xl font-semibold mb-8">Desktop</h2>
        <div className="divide-y divide-border">
          <PlatformRow name="macOS" status="Coming eventually" />
          <PlatformRow name="Windows" status="Coming eventually" />
          <PlatformRow name="Linux" status="Coming eventually" />
        </div>
      </section>
    </SiteShell>
  );
}
