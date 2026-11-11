export type Plural = { one: string; other: string };

/** Replaces `{name}` placeholders. */
export function fmt(template: string, vars: Record<string, string | number> = {}): string {
  return template.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

export function plural(n: number, forms: Plural, vars: Record<string, string | number> = {}): string {
  return fmt(n === 1 ? forms.one : forms.other, { n: n.toLocaleString("en-US"), ...vars });
}
