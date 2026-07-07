import { Link } from "@tanstack/react-router";

export function SiteHeader() {
  return (
    <header className="flex items-center justify-between">
      <Link to="/" className="flex items-center gap-3">
        <img src="/logo.png" alt="Boppa" className="w-7 h-7 rounded-md" />
        <span className="text-lg font-medium">Boppa</span>
      </Link>
      <nav className="flex items-center gap-6">
        <Link to="/docs" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
          Docs
        </Link>
        <Link
          to="/download"
          className="text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          Download
        </Link>
        <a
          href="https://discord.gg/zk6FhWNnM"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Discord"
          className="text-muted-foreground hover:text-foreground transition-colors inline-flex items-center"
        >
          <span
            aria-hidden="true"
            className="icon-mask w-[18px] h-[18px]"
            style={{ WebkitMaskImage: "url(/icons/discord.svg)", maskImage: "url(/icons/discord.svg)" }}
          />
        </a>
        <a
          href="https://reddit.com/r/BoppaApp"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Reddit"
          className="text-muted-foreground hover:text-foreground transition-colors inline-flex items-center"
        >
          <span
            aria-hidden="true"
            className="icon-mask w-[18px] h-[18px]"
            style={{ WebkitMaskImage: "url(/icons/reddit.svg)", maskImage: "url(/icons/reddit.svg)" }}
          />
        </a>
        <a
          href="https://github.com/boppa-app/Boppa"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="GitHub"
          className="text-muted-foreground hover:text-foreground transition-colors inline-flex items-center"
        >
          <span
            aria-hidden="true"
            className="icon-mask w-[18px] h-[18px]"
            style={{ WebkitMaskImage: "url(/icons/github.svg)", maskImage: "url(/icons/github.svg)" }}
          />
        </a>
      </nav>
    </header>
  );
}
