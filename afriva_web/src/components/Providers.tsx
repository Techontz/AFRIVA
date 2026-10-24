"use client";

import { Toaster } from "sonner";
import { AuthProvider } from "@/lib/auth";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      {children}
      <Toaster
        theme="dark"
        position="top-center"
        richColors
        toastOptions={{
          style: {
            background: "#1A1A1A",
            border: "1px solid #262626",
            color: "#fff",
            fontFamily: "var(--font-jakarta)",
          },
        }}
      />
    </AuthProvider>
  );
}
