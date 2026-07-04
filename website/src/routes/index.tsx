import { createFileRoute } from "@tanstack/react-router";
import { SiteFooter } from "~/components/site-footer";
import { SiteHeader } from "~/components/site-header";
import { pageMeta } from "~/meta";

export const Route = createFileRoute("/")({
  head: () =>
    pageMeta(
      "Boppa — a scriptable music player for iOS",
      "Boppa is an open-source iOS music player that streams from any site you can script, using pluggable media sources.",
      "/",
    ),
  component: Home,
});

function Home() {
  return (
    <div className="bg-background">
      <div className="relative p-6 pb-10 md:px-32 md:pt-20 md:pb-12 max-w-7xl mx-auto">
        <nav className="mb-16">
          <SiteHeader />
        </nav>

        <div className="space-y-6">
          <h1 className="text-3xl md:text-5xl font-medium tracking-tight">Music for all</h1>
          <p className="text-white/70 text-lg leading-relaxed max-w-lg">
            Turn any website into a native music player.
          </p>
        </div>
      </div>

      <SiteFooter />
    </div>
  );
}
