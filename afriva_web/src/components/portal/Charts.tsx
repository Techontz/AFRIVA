"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "../ui/Feedback";

const fallback = () => <Skeleton className="h-[260px] w-full rounded-xl" />;

// recharts is large: load it only on pages that render a chart, after hydration.
export const TrendChart = dynamic(() => import("./ChartsImpl").then((m) => m.TrendChart), { ssr: false, loading: fallback });
export const RankBarChart = dynamic(() => import("./ChartsImpl").then((m) => m.RankBarChart), { ssr: false, loading: fallback });
