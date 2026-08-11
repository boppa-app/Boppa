import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { AlertCircle, CornerDownLeft, Loader2, Mail } from "lucide-react";
import { joinWaitlist, type WaitlistPlatform } from "~/server/waitlist";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function WaitlistForm({
  platform,
  isOpen,
  onOpen,
}: {
  platform: WaitlistPlatform;
  isOpen: boolean;
  onOpen: () => void;
}) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "invalid">("idle");
  const inputRef = useRef<HTMLInputElement>(null);
  const formRef = useRef<HTMLFormElement>(null);
  const [frozenWidth, setFrozenWidth] = useState<number | null>(null);

  useLayoutEffect(() => {
    if (isOpen && inputRef.current && frozenWidth === null) {
      setFrozenWidth(Math.ceil(inputRef.current.getBoundingClientRect().width));
    }
  }, [isOpen, frozenWidth]);

  useEffect(() => {
    if (status !== "invalid") return;
    const clearIfOutside = (e: PointerEvent) => {
      if (!formRef.current?.contains(e.target as Node)) {
        setStatus("idle");
      }
    };
    document.addEventListener("pointerdown", clearIfOutside);
    return () => document.removeEventListener("pointerdown", clearIfOutside);
  }, [status]);

  if (status === "done") {
    return (
      <div className="h-9 flex items-center">
        <span className="text-sm text-muted-foreground">You're on the list</span>
      </div>
    );
  }

  if (!isOpen) {
    return (
      <button
        type="button"
        onClick={onOpen}
        className="h-9 inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
      >
        <Mail className="w-[18px] h-[18px]" />
        Notify me when available
      </button>
    );
  }

  const isInvalid = status === "invalid";

  return (
    <form
      ref={formRef}
      className="w-fit"
      noValidate
      onSubmit={async (e) => {
        e.preventDefault();
        if (!EMAIL_RE.test(email)) {
          setStatus("invalid");
          return;
        }
        setStatus("loading");
        try {
          await joinWaitlist({ data: { email, platform } });
          setStatus("done");
        } catch {
          setStatus("invalid");
        }
      }}
    >
      <div className="relative flex items-center">
        <input
          ref={inputRef}
          type="email"
          autoFocus
          placeholder="Enter your email here"
          value={email}
          onChange={(e) => {
            setEmail(e.target.value);
            if (isInvalid) setStatus("idle");
          }}
          onBlur={() => {
            if (isInvalid) setStatus("idle");
          }}
          style={
            frozenWidth
              ? ({ width: frozenWidth, fieldSizing: "fixed" } as React.CSSProperties)
              : undefined
          }
          className={`box-border h-9 rounded-md border bg-transparent pl-3 pr-8 text-base sm:text-sm outline-none [field-sizing:content] ${
            isInvalid
              ? "border-red-500"
              : "border-border focus:ring-2 focus:ring-primary"
          }`}
        />
        {isInvalid ? (
          <AlertCircle className="absolute right-2 w-4 h-4 text-red-500 pointer-events-none" />
        ) : (
          <button
            type="submit"
            aria-label="Notify me"
            disabled={status === "loading"}
            className="absolute right-2 text-muted-foreground hover:text-foreground transition-colors disabled:opacity-50"
          >
            {status === "loading" ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <CornerDownLeft className="w-4 h-4" />
            )}
          </button>
        )}
      </div>
    </form>
  );
}
