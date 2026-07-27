"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { navigation } from "@/lib/navigation";

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="hidden min-h-screen w-72 shrink-0 border-r border-white/10 bg-zinc-950 lg:block">
      <div className="sticky top-0 flex h-screen flex-col p-5">
        <div className="mb-8 rounded-2xl border border-violet-500/20 bg-violet-500/10 p-4">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-violet-300">
            Enterprise OS
          </p>
          <h1 className="mt-1 text-2xl font-black tracking-tight text-white">
            VIVID+
          </h1>
          <p className="mt-1 text-sm text-zinc-400">Orlando · Main Location</p>
        </div>

        <nav className="space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const Icon = item.icon;
            const active =
              item.href === "/dashboard"
                ? pathname === "/dashboard"
                : pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                href={item.href}
                className={[
                  "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition",
                  active
                    ? "bg-white text-zinc-950"
                    : "text-zinc-400 hover:bg-white/5 hover:text-white",
                ].join(" ")}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="mt-auto rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4">
          <p className="text-sm font-semibold text-emerald-300">Systems online</p>
          <p className="mt-1 text-xs text-zinc-400">
            Database migrations 001–007 active
          </p>
        </div>
      </div>
    </aside>
  );
}
