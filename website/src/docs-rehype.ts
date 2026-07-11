import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";
import { createHighlighterCore, type HighlighterCore } from "shiki/core";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";
import type { PluggableList } from "unified";

export const docsRemarkPlugins: PluggableList = [remarkGfm];

let docsHighlighter: Promise<HighlighterCore> | undefined;

export function getDocsHighlighter(): Promise<HighlighterCore> {
  docsHighlighter ??= Promise.all([
    import("shiki/themes/catppuccin-mocha.mjs"),
    import("shiki/langs/bash.mjs"),
    import("shiki/langs/json.mjs"),
    import("shiki/langs/javascript.mjs"),
    import("shiki/langs/swift.mjs"),
    import("shiki/langs/yaml.mjs"),
  ]).then(([theme, bash, json, javascript, swift, yaml]) =>
    createHighlighterCore({
      themes: [theme.default],
      langs: [bash.default, json.default, javascript.default, swift.default, yaml.default],
      engine: createJavaScriptRegexEngine(),
    }),
  );
  return docsHighlighter;
}

export const docsRehypePlugins: PluggableList = [
  rehypeSlug,
  [
    rehypeAutolinkHeadings,
    {
      behavior: "prepend",
      properties: { className: "heading-anchor", ariaLabel: "Link to this section" },
      content: {
        type: "element",
        tagName: "span",
        properties: { className: "heading-anchor-icon", ariaHidden: "true" },
        children: [{ type: "text", value: "#" }],
      },
    },
  ],
];
