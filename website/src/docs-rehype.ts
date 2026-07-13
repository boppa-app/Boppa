import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeSlug from "rehype-slug";
import remarkGfm from "remark-gfm";
import { createHighlighterCoreSync, type HighlighterCore } from "shiki/core";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";
import catppuccinMocha from "shiki/themes/catppuccin-mocha.mjs";
import bash from "shiki/langs/bash.mjs";
import json from "shiki/langs/json.mjs";
import javascript from "shiki/langs/javascript.mjs";
import swift from "shiki/langs/swift.mjs";
import yaml from "shiki/langs/yaml.mjs";
import type { PluggableList } from "unified";

export const docsRemarkPlugins: PluggableList = [remarkGfm];

export const docsHighlighter: HighlighterCore = createHighlighterCoreSync({
  themes: [catppuccinMocha],
  langs: [bash, json, javascript, swift, yaml],
  engine: createJavaScriptRegexEngine(),
});

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
