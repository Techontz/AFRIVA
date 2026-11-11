"use client";

import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useLocale, useT } from "@/i18n/client";
import { formatCompact, shortDate } from "@/lib/format";
import { EmptyState, Skeleton } from "../ui/Feedback";

const AXIS = { fill: "var(--color-text-dim)", fontSize: 11 };
const GRID = "var(--color-border)";

function ChartTooltip({
  active,
  payload,
  label,
  format,
  labelFormat,
}: {
  active?: boolean;
  payload?: { value: number }[];
  label?: string;
  format: (v: number) => string;
  labelFormat?: (l: string) => string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-xl border border-border bg-surface-2 px-3 py-2 text-xs shadow-xl">
      <p className="text-text-muted">{labelFormat ? labelFormat(String(label)) : label}</p>
      <p className="mt-0.5 text-sm font-bold text-text">{format(Number(payload[0]!.value))}</p>
    </div>
  );
}

/** Single-series trend (one measure over time). Title names the series, so no legend. */
export function TrendChart({
  data,
  loading,
  height = 260,
  format = (v) => formatCompact(v),
  color = "#E90204",
  id,
}: {
  data: { date: string; value: number }[];
  loading?: boolean;
  height?: number;
  format?: (v: number) => string;
  color?: string;
  id: string;
}) {
  const locale = useLocale();
  const t = useT().portal;
  const dateLabel = (v: string) => shortDate(v, locale);
  if (loading) return <div style={{ height }} className="skeleton w-full rounded-xl" />;
  if (!data.length) return <EmptyState icon="chart" title={t.noDataPeriod} className="py-10" />;
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
          <defs>
            <linearGradient id={`fill-${id}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity={0.35} />
              <stop offset="100%" stopColor={color} stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke={GRID} vertical={false} />
          <XAxis
            dataKey="date"
            tick={AXIS}
            tickLine={false}
            axisLine={false}
            tickFormatter={dateLabel}
            minTickGap={24}
          />
          <YAxis tick={AXIS} tickLine={false} axisLine={false} tickFormatter={(v) => formatCompact(v)} width={48} />
          <Tooltip
            cursor={{ stroke: "var(--color-surface-3)", strokeWidth: 1 }}
            content={<ChartTooltip format={format} labelFormat={dateLabel} />}
          />
          <Area
            type="monotone"
            dataKey="value"
            stroke={color}
            strokeWidth={2}
            fill={`url(#fill-${id})`}
            activeDot={{ r: 5, stroke: "var(--color-surface)", strokeWidth: 2, fill: color }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

/** Magnitude by category: horizontal bars sorted descending. */
export function RankBarChart({
  data,
  loading,
  format = (v) => formatCompact(v),
  color = "#E90204",
}: {
  data: { label: string; value: number }[];
  loading?: boolean;
  format?: (v: number) => string;
  color?: string;
}) {
  const t = useT().portal;
  if (loading) return <Skeleton className="h-[260px] w-full rounded-xl" />;
  if (!data.length) return <EmptyState icon="chart" title={t.noData} className="py-10" />;
  const sorted = [...data].sort((a, b) => b.value - a.value);
  const height = Math.max(160, sorted.length * 34 + 16);
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={sorted} layout="vertical" margin={{ top: 0, right: 16, left: 0, bottom: 0 }} barCategoryGap={8}>
          <CartesianGrid stroke={GRID} horizontal={false} />
          <XAxis type="number" tick={AXIS} tickLine={false} axisLine={false} tickFormatter={(v) => formatCompact(v)} />
          <YAxis
            type="category"
            dataKey="label"
            tick={{ ...AXIS, fill: "var(--color-text-muted)" }}
            tickLine={false}
            axisLine={false}
            width={96}
          />
          <Tooltip cursor={{ fill: "var(--color-surface-2)", fillOpacity: 0.5 }} content={<ChartTooltip format={format} />} />
          <Bar dataKey="value" fill={color} radius={[0, 4, 4, 0]} maxBarSize={18} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
