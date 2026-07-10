export function StoreLink() {
  return (
    <a
      href="https://www.apple.com/app-store/"
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
    >
      <span
        aria-hidden="true"
        className="icon-mask w-[18px] h-[18px]"
        style={{
          WebkitMaskImage: "url(/icons/apple.svg)",
          maskImage: "url(/icons/apple.svg)",
        }}
      />
      Get it on the App Store
    </a>
  );
}
