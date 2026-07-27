import {
  Boxes,
  CircleAlert,
  PackageCheck,
  ScanLine,
  Sparkles,
  Users,
} from "lucide-react";
import { StatCard } from "@/components/dashboard/stat-card";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function money(cents: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
}

export default async function DashboardPage() {
  const supabase = await createClient();

  const [
    productsResult,
    customersResult,
    inventoryResult,
    lowStockResult,
    invoicesResult,
  ] = await Promise.all([
    supabase.from("products").select("id", { count: "exact", head: true }),
    supabase.from("customers").select("id", { count: "exact", head: true }),
    supabase.from("inventory_stock_summary").select("inventory_value_cents"),
    supabase
      .from("inventory_stock_summary")
      .select("product_id", { count: "exact", head: true })
      .eq("is_low_stock", true),
    supabase
      .from("invoice_scans")
      .select("id", { count: "exact", head: true })
      .in("status", [
        "uploaded",
        "extracting",
        "matching",
        "needs_review",
      ]),
  ]);

  const inventoryValue =
    inventoryResult.data?.reduce(
      (sum, row) => sum + Number(row.inventory_value_cents ?? 0),
      0,
    ) ?? 0;

  const errors = [
    productsResult.error,
    customersResult.error,
    inventoryResult.error,
    lowStockResult.error,
    invoicesResult.error,
  ].filter(Boolean);

  return (
    <div className="space-y-8">
      <section className="flex flex-col justify-between gap-5 md:flex-row md:items-end">
        <div>
          <p className="text-sm font-semibold text-violet-300">
            Enterprise dashboard
          </p>
          <h2 className="mt-1 text-4xl font-black tracking-tight">
            Business at a glance
          </h2>
          <p className="mt-2 max-w-2xl text-zinc-400">
            Live operational data from your VIVID+ PostgreSQL foundation.
          </p>
        </div>

        <div
          className={[
            "rounded-full border px-4 py-2 text-sm font-semibold",
            errors.length === 0
              ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300"
              : "border-amber-500/30 bg-amber-500/10 text-amber-300",
          ].join(" ")}
        >
          {errors.length === 0
            ? "Database connected"
            : "Check Supabase environment"}
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Products"
          value={String(productsResult.count ?? 0)}
          helper="Catalog records"
          icon={PackageCheck}
        />
        <StatCard
          label="Customers"
          value={String(customersResult.count ?? 0)}
          helper="Shared CRM profiles"
          icon={Users}
        />
        <StatCard
          label="Inventory value"
          value={money(inventoryValue)}
          helper="Weighted-average valuation"
          icon={Boxes}
        />
        <StatCard
          label="Low stock"
          value={String(lowStockResult.count ?? 0)}
          helper="At or below reorder point"
          icon={CircleAlert}
        />
      </section>

      <section className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
        <article className="rounded-3xl border border-white/10 bg-gradient-to-br from-violet-500/15 via-white/[0.04] to-transparent p-6">
          <div className="flex items-center gap-3">
            <div className="rounded-xl bg-violet-500/20 p-3 text-violet-300">
              <Sparkles className="h-5 w-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold">VIVID AI Operations</h3>
              <p className="text-sm text-zinc-400">
                Invoice automation foundation ready
              </p>
            </div>
          </div>

          <div className="mt-8 grid gap-3 sm:grid-cols-3">
            {[
              ["1", "Upload invoice"],
              ["2", "AI matches products"],
              ["3", "Inventory posts"],
            ].map(([step, label]) => (
              <div
                key={step}
                className="rounded-2xl border border-white/10 bg-black/20 p-4"
              >
                <p className="text-xs font-black text-violet-300">STEP {step}</p>
                <p className="mt-2 text-sm font-semibold text-white">{label}</p>
              </div>
            ))}
          </div>
        </article>

        <article className="rounded-3xl border border-white/10 bg-white/[0.04] p-6">
          <ScanLine className="h-6 w-6 text-violet-300" />
          <p className="mt-5 text-sm text-zinc-400">
            Invoices needing attention
          </p>
          <p className="mt-1 text-4xl font-black">
            {invoicesResult.count ?? 0}
          </p>
          <p className="mt-2 text-sm text-zinc-500">
            Uploaded, processing, matching, or waiting for review
          </p>
        </article>
      </section>

      {errors.length > 0 && (
        <section className="rounded-2xl border border-amber-500/20 bg-amber-500/10 p-5 text-sm text-amber-100">
          Supabase returned an error. Confirm the URL and publishable key in
          <code className="mx-1 rounded bg-black/20 px-1.5 py-0.5">
            .env.local
          </code>
          and verify that Migration 007 exists locally.
        </section>
      )}
    </div>
  );
}
