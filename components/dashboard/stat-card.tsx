import type { LucideIcon } from "lucide-react";

type StatCardProps = {
  label: string;
  value: string;
  helper: string;
  icon: LucideIcon;
};

export function StatCard({ label, value, helper, icon: Icon }: StatCardProps) {
  return (
    <article className="rounded-2xl border border-white/10 bg-white/[0.04] p-5 shadow-2xl shadow-black/10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-zinc-400">{label}</p>
          <p className="mt-2 text-3xl font-black tracking-tight text-white">
            {value}
          </p>
          <p className="mt-2 text-xs text-zinc-500">{helper}</p>
        </div>

        <div className="rounded-xl bg-violet-500/15 p-3 text-violet-300">
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </article>
  );
}
