import type { ElementType } from "react";

type BusinessPulseItem = {
  label: string;
  value: number;
  icon: ElementType;
};

type Props = {
  items: BusinessPulseItem[];
  whole: Intl.NumberFormat;
};

export default function BusinessPulse({ items, whole }: Props) {
  return (
    <div className="grid gap-3">
      {items.map((item) => {
        const Icon = item.icon;

        return (
          <div
            key={item.label}
            className="flex items-center justify-between rounded-2xl border border-white/5 bg-black/20 px-4 py-3"
          >
            <div className="flex items-center gap-3">
              <div className="rounded-xl bg-white/5 p-2 text-zinc-400">
                <Icon className="h-4 w-4" />
              </div>

              <span className="text-sm text-zinc-400">{item.label}</span>
            </div>

            <span className="text-lg font-black">
              {whole.format(item.value)}
            </span>
          </div>
        );
      })}
    </div>
  );
}