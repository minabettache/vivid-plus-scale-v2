import type { ReactNode } from "react";
import { Sidebar } from "./sidebar";

export function DashboardShell({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-zinc-950 text-white">
      <div className="flex">
        <Sidebar />
        <main className="min-w-0 flex-1">
          <header className="sticky top-0 z-20 border-b border-white/10 bg-zinc-950/85 px-5 py-4 backdrop-blur-xl md:px-8">
            <div className="mx-auto flex max-w-7xl items-center justify-between">
              <div>
                <p className="text-xs uppercase tracking-[0.24em] text-zinc-500">
                  VIVID+ Command Center
                </p>
                <p className="font-semibold text-white">Business operations</p>
              </div>
              <div className="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-zinc-300">
                Local Development
              </div>
            </div>
          </header>

          <div className="mx-auto max-w-7xl p-5 md:p-8">{children}</div>
        </main>
      </div>
    </div>
  );
}
