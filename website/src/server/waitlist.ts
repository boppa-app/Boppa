import { createServerFn } from "@tanstack/react-start";

export const WAITLIST_PLATFORMS = ["android", "macos", "windows", "linux"] as const;
export type WaitlistPlatform = (typeof WAITLIST_PLATFORMS)[number];

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type JoinWaitlistInput = {
  email: string;
  platform: WaitlistPlatform;
};

export const joinWaitlist = createServerFn({ method: "POST" })
  .validator((data: unknown): JoinWaitlistInput => {
    const { email, platform } = (data ?? {}) as Record<string, unknown>;
    if (typeof email !== "string" || !EMAIL_RE.test(email)) {
      throw new Error("Enter a valid email address.");
    }
    if (typeof platform !== "string" || !WAITLIST_PLATFORMS.includes(platform as WaitlistPlatform)) {
      throw new Error("Invalid platform.");
    }
    return { email: email.trim().toLowerCase(), platform: platform as WaitlistPlatform };
  })
  .handler(async ({ data }) => {
    const { env } = await import("cloudflare:workers");
    await env.DB.prepare(
      `INSERT INTO waitlist (email, platform, created_at) VALUES (?, ?, ?)
       ON CONFLICT (email, platform) DO NOTHING`,
    )
      .bind(data.email, data.platform, Date.now())
      .run();
    return { ok: true as const };
  });
