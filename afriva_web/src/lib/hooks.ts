"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { normalizePage, request } from "./api";
import type { PageMeta } from "./types";

type Query = Record<string, string | number | boolean | null | undefined>;

interface State<T> {
  data: T | null;
  meta: PageMeta | null;
  loading: boolean;
  error: Error | null;
}

/**
 * Client-side GET with auth token. `path = null` skips the request.
 * Returns `data` from the envelope; `meta` when present.
 */
export function useApi<T>(path: string | null, query?: Query) {
  const queryKey = JSON.stringify(query ?? {});
  const [state, setState] = useState<State<T>>({ data: null, meta: null, loading: !!path, error: null });
  const [tick, setTick] = useState(0);
  const latest = useRef(0);

  useEffect(() => {
    if (!path) return;
    const id = ++latest.current;
    const ctrl = new AbortController();
    request<{ data: T; meta?: PageMeta }>(path, { query: JSON.parse(queryKey) as Query, signal: ctrl.signal })
      .then((res) => {
        if (id !== latest.current) return;
        setState({ data: res?.data ?? null, meta: res?.meta ?? null, loading: false, error: null });
      })
      .catch((error: Error) => {
        if (error?.name === "AbortError" || id !== latest.current) return;
        setState((s) => ({ ...s, loading: false, error }));
      });
    return () => ctrl.abort();
  }, [path, queryKey, tick]);

  const reload = useCallback(() => {
    setState((s) => ({ ...s, loading: true }));
    setTick((t) => t + 1);
  }, []);

  const mutate = useCallback((updater: (d: T | null) => T | null) => {
    setState((s) => ({ ...s, data: updater(s.data) }));
  }, []);

  return { ...state, loading: path ? state.loading : false, reload, mutate };
}

/** Like useApi but normalises list/paginated payloads into `{items, meta}`. */
export function useList<T>(path: string | null, query?: Query) {
  const queryKey = JSON.stringify(query ?? {});
  const [state, setState] = useState<{ items: T[]; meta: PageMeta | null; loading: boolean; error: Error | null }>({
    items: [],
    meta: null,
    loading: !!path,
    error: null,
  });
  const [tick, setTick] = useState(0);
  const latest = useRef(0);

  useEffect(() => {
    if (!path) return;
    const id = ++latest.current;
    const ctrl = new AbortController();
    request<unknown>(path, { query: JSON.parse(queryKey) as Query, signal: ctrl.signal })
      .then((res) => {
        if (id !== latest.current) return;
        const { items, meta } = normalizePage<T>(res);
        setState({ items, meta, loading: false, error: null });
      })
      .catch((error: Error) => {
        if (error?.name === "AbortError" || id !== latest.current) return;
        setState((s) => ({ ...s, loading: false, error }));
      });
    return () => ctrl.abort();
  }, [path, queryKey, tick]);

  const reload = useCallback(() => {
    setState((s) => ({ ...s, loading: true }));
    setTick((t) => t + 1);
  }, []);

  const setItems = useCallback((updater: (items: T[]) => T[]) => {
    setState((s) => ({ ...s, items: updater(s.items) }));
  }, []);

  return { ...state, loading: path ? state.loading : false, reload, setItems };
}

/** Debounced value. */
export function useDebounced<T>(value: T, ms = 300): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}
