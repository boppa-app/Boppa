import type { ReactNode } from "react";
import { SiteFooter } from "~/components/site-footer";
import { SiteHeader } from "~/components/site-header";

export function SiteShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <main className="max-w-5xl p-6 md:p-20 mx-auto">
        <div className="mb-12">
          <SiteHeader />
        </div>
        {children}
      </main>
      <SiteFooter />
    </div>
  );
}
