import * as React from "react";
import ReactMarkdown, { type Components } from "react-markdown";
import { docsHighlighter, docsRehypePlugins, docsRemarkPlugins } from "~/docs-rehype";

function getCodeText(children: React.ReactNode): string {
  return React.Children.toArray(children).join("");
}

function getLanguage(className: string | undefined): string | undefined {
  return className?.match(/language-([^\s]+)/)?.[1];
}

function DocsPre({
  children,
  node: _node,
  ...props
}: React.ComponentProps<"pre"> & { node?: unknown }) {
  const codeElement = React.Children.only(children);
  const codeProps = React.isValidElement<React.ComponentProps<"code">>(codeElement)
    ? codeElement.props
    : undefined;
  const code = getCodeText(codeProps?.children);
  const language = getLanguage(codeProps?.className);

  if (language && docsHighlighter.getLoadedLanguages().includes(language)) {
    const html = docsHighlighter.codeToHtml(code.replace(/\n$/, ""), {
      lang: language,
      theme: "catppuccin-mocha",
    });
    return <div dangerouslySetInnerHTML={{ __html: html }} />;
  }

  return <pre {...props}>{children}</pre>;
}

const docsMarkdownComponents: Components = {
  pre: DocsPre,
};

export function DocsMarkdown({ children }: { children: string }) {
  return (
    <div className="docs-prose">
      <ReactMarkdown
        remarkPlugins={docsRemarkPlugins}
        rehypePlugins={docsRehypePlugins}
        components={docsMarkdownComponents}
      >
        {children}
      </ReactMarkdown>
    </div>
  );
}
