import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { SiteShell } from "~/components/site-shell";
import { StoreLink } from "~/components/store-link";
import { WaitlistForm } from "~/components/waitlist-form";
import { pageMeta } from "~/meta";
import type { WaitlistPlatform } from "~/server/waitlist";

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

function PlatformRow({
  name,
  status,
  action,
}: {
  name: string;
  status?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 py-5 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between">
      <span className="font-medium">{name}</span>
      {action ?? <StatusPill label={status ?? ""} />}
    </div>
  );
}

function Download() {
  const [openPlatform, setOpenPlatform] = useState<WaitlistPlatform | null>(null);

  return (
    <SiteShell>
      <h1 className="text-3xl md:text-4xl font-semibold tracking-tight mb-2">
        Download
      </h1>
      <p className="text-muted-foreground mb-10">
        iOS only today.
      </p>

      <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8 mb-6">
        <h2 className="text-2xl font-semibold mb-8">Mobile</h2>
        <div className="divide-y divide-border">
          <PlatformRow name="iOS" action={<StoreLink />} />
          <PlatformRow
            name="Android"
            action={
              <WaitlistForm
                platform="android"
                isOpen={openPlatform === "android"}
                onOpen={() => setOpenPlatform("android")}
              />
            }
          />
        </div>
      </section>

      <section className="rounded-xl border border-border bg-card/40 p-6 md:p-8">
        <h2 className="text-2xl font-semibold mb-8">Desktop</h2>
        <div className="divide-y divide-border">
          <PlatformRow
            name="macOS"
            action={
              <WaitlistForm
                platform="macos"
                isOpen={openPlatform === "macos"}
                onOpen={() => setOpenPlatform("macos")}
              />
            }
          />
          <PlatformRow
            name="Windows"
            action={
              <WaitlistForm
                platform="windows"
                isOpen={openPlatform === "windows"}
                onOpen={() => setOpenPlatform("windows")}
              />
            }
          />
          <PlatformRow
            name="Linux"
            action={
              <WaitlistForm
                platform="linux"
                isOpen={openPlatform === "linux"}
                onOpen={() => setOpenPlatform("linux")}
              />
            }
          />
        </div>
      </section>
    </SiteShell>
  );
}
