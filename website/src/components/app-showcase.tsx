import { ChevronLeft, ChevronRight } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import type { CSSProperties, PointerEvent as ReactPointerEvent } from "react";

const SWIPE_THRESHOLD_PX = 50;
const DRAG_THRESHOLD_PX = 10;

const SCREENSHOTS = [
  {
    src: "/screenshots/search.webp",
    alt: "Boppa search results for a song",
  },
  {
    src: "/screenshots/likes-menu.webp",
    alt: "Boppa Likes list with a track context menu open",
  },
  {
    src: "/screenshots/home.webp",
    alt: "Boppa home screen with search, recently played, and recently viewed",
  },
  {
    src: "/screenshots/library.webp",
    alt: "Boppa library screen with pinned playlists, likes, playlists, and albums",
  },
  {
    src: "/screenshots/queue.webp",
    alt: "Boppa queue with drag to reorder tracks",
  },
] as const;

const DEFAULT_INDEX = 2;

const TRACK_TRANSFORM_CLASSES =
  "translate-x-[calc(50%_-_36%_-_var(--active-index)*(72%_+_24px))] " +
  "sm:translate-x-[calc(50%_-_26%_-_var(--active-index)*(52%_+_24px))] " +
  "md:translate-x-[calc(50%_-_18%_-_var(--active-index)*(36%_+_24px))] " +
  "lg:translate-x-[calc(50%_-_15%_-_var(--active-index)*(30%_+_24px))]";

export function AppShowcase() {
  const [activeIndex, setActiveIndex] = useState(DEFAULT_INDEX);
  const dragStart = useRef<{ x: number; y: number } | null>(null);
  const dragAxis = useRef<"x" | "y" | null>(null);
  const wasHorizontalDrag = useRef(false);

  const goTo = (index: number) => {
    setActiveIndex(Math.min(SCREENSHOTS.length - 1, Math.max(0, index)));
  };

  const handleClick = (fn: () => void) => () => {
    if (wasHorizontalDrag.current) {
      wasHorizontalDrag.current = false;
      return;
    }
    fn();
  };

  const handlePointerDown = (e: ReactPointerEvent) => {
    dragStart.current = { x: e.clientX, y: e.clientY };
    dragAxis.current = null;
  };

  const handlePointerMove = (e: ReactPointerEvent) => {
    if (!dragStart.current || dragAxis.current) return;
    const deltaX = e.clientX - dragStart.current.x;
    const deltaY = e.clientY - dragStart.current.y;
    if (Math.abs(deltaX) > DRAG_THRESHOLD_PX || Math.abs(deltaY) > DRAG_THRESHOLD_PX) {
      dragAxis.current = Math.abs(deltaX) > Math.abs(deltaY) ? "x" : "y";
    }
  };

  const handlePointerUp = (e: ReactPointerEvent) => {
    if (!dragStart.current) return;
    const deltaX = e.clientX - dragStart.current.x;
    const wasHorizontal = dragAxis.current === "x";
    dragStart.current = null;
    dragAxis.current = null;
    if (wasHorizontal && Math.abs(deltaX) > SWIPE_THRESHOLD_PX) {
      wasHorizontalDrag.current = true;
      goTo(activeIndex + (deltaX < 0 ? 1 : -1));
    }
  };

  const handlePointerCancel = () => {
    dragStart.current = null;
    dragAxis.current = null;
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") {
        setActiveIndex((prev) => Math.max(0, prev - 1));
      } else if (e.key === "ArrowRight") {
        setActiveIndex((prev) => Math.min(SCREENSHOTS.length - 1, prev + 1));
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  return (
    <section className="py-4 md:py-8">
      <div className="relative">
        <div
          aria-hidden="true"
          className="absolute inset-y-0 left-1/2 w-screen -translate-x-1/2 pointer-events-none"
          style={{ clipPath: "inset(-9999px 0)" }}
        >
          <div
            className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[85%] sm:w-[85%] md:w-[70%] lg:w-[60%] h-[140%] sm:h-[160%]"
            style={{
              background:
                "radial-gradient(ellipse, color-mix(in srgb, var(--color-primary) 38%, transparent) 0%, transparent 60%)",
            }}
          />
        </div>

        <div
          className="relative overflow-hidden touch-pan-y"
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerCancel}
        >
          <div
            className={`flex gap-6 ${TRACK_TRANSFORM_CLASSES}`}
            style={
              {
                "--active-index": activeIndex,
                transition:
                  "transform 0.6s cubic-bezier(0.22, 1, 0.36, 1), translate 0.6s cubic-bezier(0.22, 1, 0.36, 1)",
              } as CSSProperties
            }
          >
            {SCREENSHOTS.map((shot, index) => {
              const distance = Math.abs(index - activeIndex);
              const isActive = distance === 0;
              return (
                <button
                  key={shot.src}
                  type="button"
                  aria-label={`Go to screenshot ${index + 1}`}
                  aria-current={isActive}
                  onClick={handleClick(() => goTo(index))}
                  className="shrink-0 w-[72%] sm:w-[52%] md:w-[36%] lg:w-[30%] appearance-none bg-transparent p-0 border-0 cursor-default transition-all duration-500 ease-out"
                  style={{
                    opacity: isActive ? 1 : distance === 1 ? 0.35 : 0.1,
                    transform: `scale(${isActive ? 1 : 0.88})`,
                  }}
                >
                  <img
                    src={shot.src}
                    alt={shot.alt}
                    draggable={false}
                    className="w-full h-auto drop-shadow-2xl"
                  />
                </button>
              );
            })}
          </div>

          <button
            type="button"
            aria-label="Previous screenshot"
            onClick={handleClick(() => goTo(activeIndex - 1))}
            disabled={activeIndex === 0}
            className="absolute left-0 top-1/2 -translate-y-1/2 flex items-center justify-center w-10 h-10 rounded-full border border-border bg-card/80 text-foreground backdrop-blur transition-opacity hover:bg-card disabled:opacity-0"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <button
            type="button"
            aria-label="Next screenshot"
            onClick={handleClick(() => goTo(activeIndex + 1))}
            disabled={activeIndex === SCREENSHOTS.length - 1}
            className="absolute right-0 top-1/2 -translate-y-1/2 flex items-center justify-center w-10 h-10 rounded-full border border-border bg-card/80 text-foreground backdrop-blur transition-opacity hover:bg-card disabled:opacity-0"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="mt-6 flex items-center justify-center gap-2">
        {SCREENSHOTS.map((shot, index) => (
          <button
            key={shot.src}
            type="button"
            aria-label={`Go to screenshot ${index + 1}`}
            onClick={() => goTo(index)}
            className={`h-1.5 rounded-full transition-all duration-300 ${
              index === activeIndex ? "w-6 bg-primary" : "w-1.5 bg-white/20"
            }`}
          />
        ))}
      </div>
    </section>
  );
}
