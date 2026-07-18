import { Link, useLocation } from "@tanstack/react-router";
import { useCallback, useEffect, useMemo, useState } from "react";
import { type DocsNavNode } from "~/docs";

interface DocsNavProps {
  nodes: DocsNavNode[];
  mobile?: boolean;
  onNavigate?: () => void;
  topLevel?: boolean;
}

const ACTIVE_OPTIONS_EXACT = { exact: true };

function nodeContainsHref(node: DocsNavNode, href: string): boolean {
  if (node.type === "page") return node.href === href;
  return node.children.some((child) => nodeContainsHref(child, href));
}

function clsx(...classes: (string | false | null | undefined)[]): string {
  return classes.filter(Boolean).join(" ");
}

function PageLink({
  node,
  mobile,
  onNavigate,
}: {
  node: Extract<DocsNavNode, { type: "page" }>;
  mobile?: boolean;
  onNavigate?: () => void;
}) {
  const location = useLocation();
  const isActive = location.pathname === node.href;

  return (
    <Link
      to={node.href}
      activeOptions={ACTIVE_OPTIONS_EXACT}
      onClick={onNavigate}
      className={clsx(
        "block px-3 py-2 text-sm rounded-md transition-colors",
        mobile
          ? "text-muted-foreground hover:text-foreground"
          : "text-muted-foreground hover:text-foreground hover:bg-muted",
        isActive && (mobile ? "text-foreground" : "bg-muted text-foreground"),
      )}
    >
      {node.label}
    </Link>
  );
}

function GroupNode({
  node,
  mobile,
  onNavigate,
  topLevel,
}: {
  node: Extract<DocsNavNode, { type: "group" }>;
  mobile?: boolean;
  onNavigate?: () => void;
  topLevel?: boolean;
}) {
  const location = useLocation();
  const currentHref = location.pathname;
  const containsActive = useMemo(() => nodeContainsHref(node, currentHref), [node, currentHref]);
  const isActive = node.href === currentHref;
  const [isOpen, setIsOpen] = useState(true);
  const toggle = useCallback(() => {
    if (containsActive) return;
    setIsOpen((open) => !open);
  }, [containsActive]);
  const expandAndNavigate = useCallback(() => {
    setIsOpen(true);
    onNavigate?.();
  }, [onNavigate]);

  useEffect(() => {
    if (containsActive) setIsOpen(true);
  }, [containsActive]);

  return (
    <div className={topLevel ? (mobile ? "mt-4 first:mt-0" : "mt-6 first:mt-0") : undefined}>
      <div
        className={clsx(
          "w-full flex items-center gap-1",
          (containsActive || isActive) && "text-foreground",
        )}
      >
        {node.href ? (
          <Link
            to={node.href}
            activeOptions={ACTIVE_OPTIONS_EXACT}
            onClick={expandAndNavigate}
            className={clsx(
              "flex-1 min-w-0 truncate px-3 py-2 rounded-md transition-colors text-left",
              topLevel ? "text-xs font-medium" : "text-sm",
              mobile
                ? "text-muted-foreground hover:text-foreground"
                : "text-muted-foreground hover:text-foreground hover:bg-muted",
              isActive && (mobile ? "text-foreground" : "bg-muted text-foreground"),
            )}
          >
            {node.label}
          </Link>
        ) : (
          <button
            type="button"
            onClick={expandAndNavigate}
            className={clsx(
              "flex-1 min-w-0 truncate px-3 py-2 rounded-md transition-colors text-left",
              topLevel ? "text-xs font-medium" : "text-sm",
              mobile
                ? "text-muted-foreground hover:text-foreground"
                : "text-muted-foreground hover:text-foreground hover:bg-muted",
            )}
          >
            {node.label}
          </button>
        )}
      </div>
      {isOpen && (
        <div className="ml-3 flex">
          <button
            type="button"
            onClick={toggle}
            disabled={containsActive}
            aria-label={`Collapse ${node.label}`}
            className={clsx(
              "group/rail relative w-3 shrink-0",
              containsActive ? "cursor-default" : "cursor-pointer",
            )}
          >
            <span
              className={clsx(
                "absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-border transition-colors",
                !containsActive && "group-hover/rail:bg-foreground/40",
              )}
            />
          </button>
          <div className="min-w-0 flex-1 space-y-0.5">
            <NavTree nodes={node.children} mobile={mobile} onNavigate={onNavigate} />
          </div>
        </div>
      )}
    </div>
  );
}

function CategoryNode({
  node,
  mobile,
  onNavigate,
}: {
  node: Extract<DocsNavNode, { type: "category" }>;
  mobile?: boolean;
  onNavigate?: () => void;
}) {
  return (
    <div className={mobile ? "space-y-1" : "space-y-1 mt-6 first:mt-0"}>
      <div className="px-3 py-2 text-xs font-medium text-foreground">{node.label}</div>
      <NavTree nodes={node.children} mobile={mobile} onNavigate={onNavigate} />
    </div>
  );
}

function NavTree({ nodes, mobile, onNavigate, topLevel }: DocsNavProps) {
  return (
    <div className="space-y-0.5">
      {nodes.map((node) => {
        if (node.type === "category") {
          return (
            <CategoryNode
              key={`category-${node.label}`}
              node={node}
              mobile={mobile}
              onNavigate={onNavigate}
            />
          );
        }
        if (node.type === "group") {
          return (
            <GroupNode
              key={`group-${node.segment}`}
              node={node}
              mobile={mobile}
              onNavigate={onNavigate}
              topLevel={topLevel}
            />
          );
        }
        return (
          <PageLink key={`page-${node.href}`} node={node} mobile={mobile} onNavigate={onNavigate} />
        );
      })}
    </div>
  );
}

export function DocsNav({ nodes, mobile, onNavigate }: DocsNavProps) {
  return (
    <div className={mobile ? undefined : "-ml-3"}>
      <NavTree nodes={nodes} mobile={mobile} onNavigate={onNavigate} topLevel />
    </div>
  );
}
