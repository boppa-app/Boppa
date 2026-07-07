export function SiteFooter() {
  return (
    <footer className="max-w-5xl mx-auto p-6 md:p-20 md:pt-0">
      <div className="border-t border-border pt-8 pb-4 grid grid-cols-2 sm:grid-cols-3 gap-8 text-sm">
        <div className="space-y-3">
          <p className="text-white/60 font-medium">Product</p>
          <div className="space-y-2">
            <a
              href="/docs"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              Docs
            </a>
          </div>
        </div>
        <div className="space-y-3">
          <p className="text-white/60 font-medium">Community</p>
          <div className="space-y-2">
            <a
              href="https://github.com/boppa-app/Boppa"
              target="_blank"
              rel="noopener noreferrer"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              GitHub
            </a>
            <a
              href="https://reddit.com/r/BoppaApp"
              target="_blank"
              rel="noopener noreferrer"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              Reddit
            </a>
            <a
              href="https://discord.gg/zk6FhWNnM"
              target="_blank"
              rel="noopener noreferrer"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              Discord
            </a>
          </div>
        </div>
        <div className="space-y-3">
          <p className="text-white/60 font-medium">Download</p>
          <div className="space-y-2">
            <a
              href="/download"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              iOS
            </a>
            <a
              href="/download"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              Android
            </a>
            <a
              href="/download"
              className="block text-muted-foreground hover:text-foreground transition-colors"
            >
              Desktop
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
