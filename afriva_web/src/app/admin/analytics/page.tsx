"use client";

import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { LoadError } from "@/components/admin/helpers";
import { RankBarChart, TrendChart } from "@/components/portal/Charts";
import { Card, DataTable, PageHeader, StatCard, Thumb } from "@/components/portal/Kit";
import { DualTrendChart, Notice, RangeSelect } from "@/components/portal/ScopeKit";
import { Button } from "@/components/ui/Button";
import { Field, Input, Select } from "@/components/ui/Form";
import { Icon } from "@/components/ui/Icon";
import { Modal } from "@/components/ui/Modal";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatMoney, formatNumber } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { useT } from "@/lib/i18n";
import {
  COST_CATEGORY_LABEL,
  DASH,
  hasPerm,
  pct,
  watchTime,
  type AnalyticsOverview,
  type OperatingCostRow,
} from "@/lib/portal";

const money = (v: number | undefined) => (v ? formatMoney(v) : DASH);
const num = (v: number | undefined) => (v ? formatNumber(v) : DASH);

/** Analytics (scope §06): every number comes from the database and real events. */
export default function AnalyticsPage() {
  const t = useT();
  const { user } = useAuth();
  const [days, setDays] = useState(30);
  const { data, loading, error, reload } = useApi<AnalyticsOverview>("/admin/analytics", { days });
  const r = data?.revenue;
  const a = data?.audience;
  const u = data?.active_users;
  const c = data?.coins;
  const p = data?.payments;

  return (
    <>
      <PageHeader
        title="AFRIVA analytics"
        description="Every number comes from the database and real events, never invented figures."
        actions={<RangeSelect value={days} onChange={setDays} />}
      />
      {error && !data ? (
        <LoadError onRetry={reload} />
      ) : (
        <div className="flex flex-col gap-4">
          {data?.alerts.map((al) => (
            <Notice key={al.code} tone={al.level === "danger" ? "danger" : "warning"} title="Cost alert">
              {al.message}
            </Notice>
          ))}

          <h2 className="text-lg font-bold">{t("Revenue")}</h2>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard label="Gross revenue" icon="wallet" accent="success" loading={loading} value={money(r?.gross)} />
            <StatCard label="Refunds" icon="refresh" loading={loading} value={money(r?.refunds)} />
            <StatCard label="Provider fees" icon="card" loading={loading} value={money(r?.fees)} />
            <StatCard label="Net revenue" icon="payout" accent="success" loading={loading} value={money(r?.net)} hint="Gross − refunds − fees" />
          </div>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
            <StatCard
              label="Streaming cost"
              icon="globe"
              accent="info"
              loading={loading}
              value={money(r?.streaming_cost)}
              hint={r?.streaming_cost_is_estimate ? "Estimate from watch time (enter the real cost below)" : "Entered by finance"}
            />
            <StatCard label="Other operating costs" icon="building" loading={loading} value={money(r?.operating_costs)} />
            <StatCard
              label="Net after costs"
              icon="chart"
              accent="success"
              loading={loading}
              value={r && (r.net || r.streaming_cost || r.operating_costs) ? formatMoney(r.net_after_costs) : DASH}
            />
          </div>
          <div className="grid gap-4 xl:grid-cols-[2fr_1fr]">
            <Card title="Gross vs net revenue">
              <DualTrendChart
                loading={loading}
                data={r?.chart ?? []}
                series={[
                  { key: "gross", label: "Gross", color: "#E1122B" },
                  { key: "net", label: "Net", color: "#22C55E" },
                ]}
                format={(v) => formatMoney(v)}
              />
            </Card>
            <Card title="Revenue by package type">
              <RankBarChart loading={loading} data={(r?.by_type ?? []).map((x) => ({ label: t(x.type), value: x.value }))} format={(v) => formatMoney(v)} />
            </Card>
          </div>

          <h2 className="mt-4 text-lg font-bold">{t("Audience")}</h2>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard label="Unique viewers" icon="users" accent="info" loading={loading} value={num(a?.unique_viewers)} />
            <StatCard label="Watch time" icon="clock" loading={loading} value={watchTime(a?.watch_seconds)} hint={a?.unique_viewers ? t("{v} per viewer", { v: watchTime(a.avg_watch_seconds_per_viewer) }) : undefined} />
            <StatCard label="Returning viewers" icon="history" loading={loading} value={a?.unique_viewers ? pct(a.retention_rate) : DASH} hint={a?.returning_viewers ? t("{n} viewers", { n: formatNumber(a.returning_viewers) }) : undefined} />
            <StatCard label="Completion rate" icon="check" accent="success" loading={loading} value={a?.sessions ? pct(a.completion_rate) : DASH} />
            <StatCard label="Views" icon="eye" loading={loading} value={num(a?.views)} />
            <StatCard label="Daily active (today)" icon="user" loading={loading} value={num(u?.dau)} hint={u?.dau_avg ? t("{n} average per day", { n: formatNumber(u.dau_avg) }) : undefined} />
            <StatCard label="Monthly active" icon="users" loading={loading} value={num(u?.mau)} hint="Last 30 days" />
            <StatCard label="Playback errors" icon="alert" loading={loading} value={num(a?.playback_errors)} />
          </div>
          <div className="grid gap-4 xl:grid-cols-3">
            <Card title="Views">
              <TrendChart id="views" loading={loading} data={a?.views_chart ?? []} format={(v) => formatNumber(v)} />
            </Card>
            <Card title="Watch time (minutes)">
              <TrendChart
                id="watch"
                loading={loading}
                color="#38BDF8"
                data={(a?.watch_time_chart ?? []).map((x) => ({ date: x.date, value: Math.round(x.value / 60) }))}
                format={(v) => formatNumber(v)}
              />
            </Card>
            <Card title="Daily active users">
              <TrendChart id="dau" loading={loading} color="#FFFFFF" data={u?.chart ?? []} format={(v) => formatNumber(v)} />
            </Card>
          </div>

          <h2 className="mt-4 text-lg font-bold">{t("Coins and payments")}</h2>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard label="Coins bought" icon="coin" loading={loading} value={num(c?.purchased)} hint={c?.bonus ? t("+{n} bonus", { n: formatNumber(c.bonus) }) : undefined} />
            <StatCard label="Coins spent" icon="coin" loading={loading} value={num(c?.spent)} />
            <StatCard label="Coins held by users" icon="wallet" loading={loading} value={num(c?.outstanding_balance)} />
            <StatCard
              label="Payment success rate"
              icon="check"
              accent="success"
              loading={loading}
              value={p?.attempts ? pct(p.success_rate) : DASH}
              hint={p?.attempts ? t("{ok} succeeded · {fail} failed of {n}", { ok: p.success, fail: p.failed, n: p.attempts }) : undefined}
            />
          </div>
          <div className="grid gap-4 xl:grid-cols-2">
            <Card title="Coins bought vs spent">
              <DualTrendChart
                loading={loading}
                data={c?.chart ?? []}
                series={[
                  { key: "bought", label: "Bought", color: "#F5C044" },
                  { key: "spent", label: "Spent", color: "#E1122B" },
                ]}
                format={(v) => formatNumber(v)}
              />
            </Card>
            <Card title="Payment attempts by method">
              <DataTable
                loading={loading}
                rows={p?.by_method ?? []}
                rowKey={(m) => m.method}
                columns={[
                  { key: "m", header: "Method", render: (m) => <span className="font-semibold">{m.name}</span> },
                  { key: "a", header: "Attempts", render: (m) => formatNumber(m.attempts) },
                  { key: "s", header: "Succeeded", render: (m) => <span className="text-success">{formatNumber(m.success)}</span> },
                  { key: "f", header: "Failed", render: (m) => <span className={m.failed ? "text-danger" : ""}>{formatNumber(m.failed)}</span> },
                  { key: "amt", header: "Amount", className: "text-right", render: (m) => money(m.amount) },
                ]}
              />
            </Card>
          </div>

          <h2 className="mt-4 text-lg font-bold">{t("Revenue by series")}</h2>
          <DataTable
            loading={loading}
            rows={data?.series ?? []}
            rowKey={(s) => s.drama_id}
            columns={[
              {
                key: "t",
                header: "Series",
                render: (s) => (
                  <div className="flex items-center gap-3">
                    <Thumb src={s.poster_url} alt={s.title} />
                    <Link href={`/admin/analytics/dramas/${s.drama_id}`} className="font-semibold hover:text-primary">
                      {s.title}
                    </Link>
                  </div>
                ),
              },
              { key: "g", header: "Revenue (gross)", render: (s) => money(s.revenue_gross) },
              { key: "c", header: "Creator share", render: (s) => money(s.creator_earnings) },
              { key: "v", header: "Views", render: (s) => num(s.views) },
              { key: "u", header: "Unique viewers", render: (s) => num(s.unique_viewers) },
              { key: "w", header: "Watch time", render: (s) => watchTime(s.watch_seconds) },
              { key: "d", header: "Completion", className: "text-right", render: (s) => (s.unique_viewers ? pct(s.completion_rate) : DASH) },
            ]}
          />

          {hasPerm(user, "finance") && <CostsCard onChanged={reload} />}
        </div>
      )}
    </>
  );
}

/** Monthly operating costs entered by finance (used for net revenue after costs). */
function CostsCard({ onChanged }: { onChanged: () => void }) {
  const t = useT();
  const costs = useApi<OperatingCostRow[]>("/admin/costs");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ period: new Date().toISOString().slice(0, 7), category: "streaming", amount: "", notes: "" });
  const [busy, setBusy] = useState(false);

  const add = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      await api.post("/admin/costs", { ...form, amount: Number(form.amount || 0), notes: form.notes || null });
      toast.success(t("Cost saved"));
      setOpen(false);
      setForm((f) => ({ ...f, amount: "", notes: "" }));
      costs.reload();
      onChanged();
    } catch (err) {
      toast.error(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async (row: OperatingCostRow) => {
    try {
      await api.del(`/admin/costs/${row.id}`);
      costs.mutate((l) => (l ?? []).filter((x) => x.id !== row.id));
      onChanged();
    } catch (err) {
      toast.error(errorMessage(err));
    }
  };

  return (
    <Card
      title="Monthly operating costs"
      className="mt-4"
      actions={
        <Button size="sm" variant="secondary" onClick={() => setOpen(true)}>
          <Icon name="plus" size={15} /> {t("Add cost")}
        </Button>
      }
    >
      <p className="mb-3 text-xs text-text-muted">
        {t("Enter real monthly costs. A streaming cost entered here replaces the estimate from watch time.")}
      </p>
      <DataTable
        loading={costs.loading}
        rows={costs.data ?? []}
        rowKey={(r) => r.id}
        columns={[
          { key: "p", header: "Month", render: (r) => r.period.slice(0, 7) },
          { key: "c", header: "Category", render: (r) => t(COST_CATEGORY_LABEL[r.category]) },
          { key: "a", header: "Amount", render: (r) => formatMoney(r.amount) },
          { key: "n", header: "Notes", render: (r) => r.notes ?? "—" },
          { key: "b", header: "Entered by", render: (r) => r.created_by ?? "—" },
          {
            key: "x",
            header: "",
            className: "text-right",
            render: (r) => (
              <button
                onClick={() => remove(r)}
                className="grid h-8 w-8 place-items-center rounded-full text-text-dim hover:bg-danger/15 hover:text-danger"
                aria-label={t("Delete")}
              >
                <Icon name="trash" size={15} />
              </button>
            ),
          },
        ]}
      />
      <Modal open={open} onClose={() => setOpen(false)} title="Add cost">
        <form onSubmit={add} className="grid gap-4 sm:grid-cols-2">
          <Field label="Month">
            <Input type="month" required value={form.period} onChange={(e) => setForm((f) => ({ ...f, period: e.target.value }))} />
          </Field>
          <Field label="Category">
            <Select value={form.category} onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}>
              {Object.entries(COST_CATEGORY_LABEL).map(([k, v]) => (
                <option key={k} value={k}>
                  {t(v)}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Amount (TZS)">
            <Input type="number" min={0} required value={form.amount} onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))} />
          </Field>
          <Field label="Notes">
            <Input value={form.notes} onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))} />
          </Field>
          <div className="flex justify-end gap-2 sm:col-span-2">
            <Button type="button" variant="ghost" onClick={() => setOpen(false)}>
              {t("Cancel")}
            </Button>
            <Button type="submit" loading={busy}>
              {t("Save")}
            </Button>
          </div>
        </form>
      </Modal>
    </Card>
  );
}
