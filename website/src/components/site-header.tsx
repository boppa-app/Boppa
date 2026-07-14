import { Link } from "@tanstack/react-router";
import { BoppaLogo, DiscordIcon, GithubIcon, RedditIcon } from "~/components/icons";

export function SiteHeader() {
  return (
    <header className="flex items-center justify-between">
      <Link to="/" className="flex items-center gap-3">
        <BoppaLogo className="w-6 h-6" />
        <span className="text-lg font-medium">Boppa</span>
      </Link>
      <nav className="flex items-center gap-6">
        <Link
          to="/docs"
          className="hidden sm:inline text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          Docs
        </Link>
        <Link
          to="/download"
          className="hidden sm:inline text-sm text-muted-foreground hover:text-foreground transition-colors"
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
          <DiscordIcon className="w-[18px] h-[18px]" />
        </a>
        <a
          href="https://reddit.com/r/BoppaApp"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Reddit"
          className="text-muted-foreground hover:text-foreground transition-colors inline-flex items-center"
        >
          <RedditIcon className="w-[18px] h-[18px]" />
        </a>
        <a
          href="https://github.com/boppa-app/Boppa"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="GitHub"
          className="text-muted-foreground hover:text-foreground transition-colors inline-flex items-center"
        >
          <GithubIcon className="w-[18px] h-[18px]" />
        </a>
      </nav>
    </header>
  );
}
