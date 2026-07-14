import { AppleIcon } from "~/components/icons";

export function StoreLink() {
  return (
    <a
      href="https://www.apple.com/app-store/"
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
    >
      <AppleIcon className="w-[18px] h-[18px]" />
      Get it on the App Store
    </a>
  );
}
