"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { api, getToken, setToken } from "./api";
import type { AuthPayload, Role, User } from "./types";

interface AuthContextValue {
  user: User | null;
  /** True until the stored token has been checked against /auth/me. */
  loading: boolean;
  login: (login: string, password: string) => Promise<User>;
  register: (data: { name: string; email?: string; phone?: string; password: string }) => Promise<User>;
  logout: () => Promise<void>;
  refresh: () => Promise<User | null>;
  setUser: (updater: (u: User | null) => User | null) => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function homeForRole(role: Role | undefined): string {
  if (role === "super_admin") return "/admin";
  if (role === "company") return "/studio";
  return "/";
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUserState] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (!getToken()) {
      setUserState(null);
      return null;
    }
    try {
      const me = await api.get<User>("/auth/me");
      setUserState(me);
      return me;
    } catch (e) {
      if ((e as { status?: number }).status === 401) {
        setToken(null);
        setUserState(null);
      }
      return null;
    }
  }, []);

  useEffect(() => {
    let alive = true;
    const initial = getToken()
      ? api.get<User>("/auth/me").then(
          (me) => alive && setUserState(me),
          (e: { status?: number }) => {
            if (e?.status === 401) setToken(null);
          },
        )
      : Promise.resolve();
    initial.finally(() => alive && setLoading(false));
    const onUnauthorized = () => {
      setToken(null);
      setUserState(null);
    };
    window.addEventListener("afriva:unauthorized", onUnauthorized);
    return () => {
      alive = false;
      window.removeEventListener("afriva:unauthorized", onUnauthorized);
    };
  }, []);

  const finishAuth = useCallback(async (payload: AuthPayload) => {
    setToken(payload.token);
    setUserState(payload.user);
    // /auth/me carries active_subscription & company details.
    const me = await api.get<User>("/auth/me").catch(() => null);
    if (me) setUserState(me);
    return me ?? payload.user;
  }, []);

  const login = useCallback(
    async (loginId: string, password: string) =>
      finishAuth(await api.post<AuthPayload>("/auth/login", { login: loginId, password })),
    [finishAuth],
  );

  const register = useCallback(
    async (data: { name: string; email?: string; phone?: string; password: string }) =>
      finishAuth(await api.post<AuthPayload>("/auth/register", data)),
    [finishAuth],
  );

  const logout = useCallback(async () => {
    try {
      await api.post("/auth/logout");
    } catch {
      /* token may already be invalid */
    }
    setToken(null);
    setUserState(null);
  }, []);

  const setUser = useCallback((updater: (u: User | null) => User | null) => setUserState(updater), []);

  const value = useMemo(
    () => ({ user, loading, login, register, logout, refresh, setUser }),
    [user, loading, login, register, logout, refresh, setUser],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
