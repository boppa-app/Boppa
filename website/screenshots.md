# Landing page screenshots

The phone mockups used in `src/components/app-showcase.tsx` (served from
`public/screenshots/`) are generated like this:

1. Take the raw screenshot on-device.
2. Drop it into [mockuphone.com](https://mockuphone.com/) and pick the
   **Apple iPhone 15 (Black)** frame. Export the **portrait** variant
   (transparent background, no perspective tilt) — that's the one that
   crops tightly and is easiest to lay out with CSS.
3. Convert the exported PNG to WebP and shrink it to the size actually
   rendered on the page (2x a ~320px-wide card is plenty):

   ```bash
   cwebp -q 82 -resize 640 0 input-portrait.png -o output.webp
   ```

   - `-q 82` — quality, keeps file size small without visible artifacts.
   - `-resize 640 0` — scale width to 640px, height auto (keeps aspect ratio).
   - Source mockups are ~1419×2796; this brings each file down to
     20-45 KB while staying crisp on retina screens.

4. Save the result into `public/screenshots/` using a name that
   describes the screen shown (not the source filename), so the
   mapping in `app-showcase.tsx` stays readable:

   | File            | Screen                                    |
   | --------------- | ------------------------------------------ |
   | `search.webp`     | Search results                            |
   | `likes-menu.webp` | Likes list with track context menu open   |
   | `home.webp`       | Home (Recently Played / Recently Viewed)  |
   | `library.webp`    | Library                                   |
   | `queue.webp`      | Queue / reorder                           |
