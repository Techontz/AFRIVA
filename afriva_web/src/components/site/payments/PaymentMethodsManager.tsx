"use client";

import { useState } from "react";
import { toast } from "sonner";
import { useLocale, useT } from "@/i18n/client";
import { fmt } from "@/i18n/format";
import { ApiError, api, errorMessage } from "@/lib/api";
import { cn, formatDate } from "@/lib/format";
import { useApi } from "@/lib/hooks";
import { normalizePhone, savedLabel, type SavedMethod } from "@/lib/payments";
import { Button } from "../../ui/Button";
import { ApiDownState } from "../../ui/Feedback";
import { Icon } from "../../ui/Icon";
import { ConfirmModal, Modal } from "../../ui/Modal";
import { PhoneField } from "./PayFields";
import { SavedMethodIcon } from "./PayMarks";

/** Account > Payments: saved mobile money numbers and cards (one tap at checkout). */
export function PaymentMethodsManager() {
  const t = useT().user.pay;
  const locale = useLocale();
  const list = useApi<SavedMethod[]>("/me/payment-methods");
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<SavedMethod | null>(null);
  const [busy, setBusy] = useState<number | "remove" | null>(null);
  const items = list.data ?? [];

  const makeDefault = async (m: SavedMethod) => {
    setBusy(m.id);
    try {
      await api.patch(`/me/payment-methods/${m.id}`);
      list.mutate((xs) => (xs ?? []).map((x) => ({ ...x, is_default: x.id === m.id })));
      toast.success(t.defaultSet);
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  const remove = async () => {
    if (!removing) return;
    setBusy("remove");
    try {
      await api.del(`/me/payment-methods/${removing.id}`);
      toast.success(t.removed);
      setRemoving(null);
      list.reload();
    } catch (e) {
      toast.error(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <section>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-lg font-extrabold tracking-tight">{t.methodsTitle}</h2>
          <p className="mt-0.5 text-sm text-text-muted">{t.methodsHint}</p>
        </div>
        <Button size="sm" variant="secondary" onClick={() => setAdding(true)}>
          <Icon name="plus" size={15} /> {t.addNumber}
        </Button>
      </div>

      <div className="mt-4">
        {list.error ? (
          <ApiDownState action={<Button variant="secondary" onClick={list.reload}>{t.retry}</Button>} />
        ) : list.loading && !list.data ? (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="skeleton h-[84px] rounded-2xl" />
            <div className="skeleton h-[84px] rounded-2xl" />
          </div>
        ) : !items.length ? (
          <button
            onClick={() => setAdding(true)}
            className="flex w-full items-center gap-4 rounded-2xl border-2 border-dashed border-border p-5 text-left transition hover:bg-surface"
          >
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-primary/12 text-primary">
              <Icon name="wallet" size={20} />
            </span>
            <span>
              <span className="block font-bold">{t.methodsEmpty}</span>
              <span className="block text-sm text-text-muted">{t.methodsEmptyHint}</span>
            </span>
          </button>
        ) : (
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {items.map((m) => {
              const label = savedLabel(m, false);
              const exp =
                m.type === "card" && m.card_exp_month && m.card_exp_year
                  ? fmt(t.expires, { date: `${String(m.card_exp_month).padStart(2, "0")}/${String(m.card_exp_year).slice(-2)}` })
                  : null;
              return (
                <li
                  key={m.id}
                  className={cn(
                    "flex flex-col gap-3 rounded-2xl bg-surface p-4 ring-1 transition",
                    m.is_default ? "ring-primary/50" : "ring-transparent",
                  )}
                >
                  <div className="flex items-center gap-3">
                    <SavedMethodIcon method={m} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-bold tabular-nums">{label.title}</p>
                      <p className="truncate text-xs text-text-muted">
                        {m.type === "card" ? exp : label.subtitle}
                        {m.last_used_at ? ` · ${fmt(t.lastUsed, { date: formatDate(m.last_used_at, false, locale) })}` : ""}
                      </p>
                    </div>
                    {m.is_expired ? (
                      <span className="rounded-full bg-danger/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-danger">
                        {t.expired}
                      </span>
                    ) : m.is_default ? (
                      <span className="flex items-center gap-1 rounded-full bg-primary/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-primary">
                        <Icon name="check" size={11} strokeWidth={3} /> {t.default}
                      </span>
                    ) : null}
                  </div>
                  <div className="flex gap-2 border-t border-border pt-3">
                    {!m.is_default && !m.is_expired && (
                      <Button size="sm" variant="ghost" loading={busy === m.id} onClick={() => makeDefault(m)}>
                        {t.makeDefault}
                      </Button>
                    )}
                    <Button size="sm" variant="ghost" className="ml-auto text-text-dim hover:text-danger" onClick={() => setRemoving(m)}>
                      <Icon name="trash" size={14} /> {t.remove}
                    </Button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <AddNumberModal
        open={adding}
        onClose={() => setAdding(false)}
        onAdded={() => {
          setAdding(false);
          list.reload();
        }}
      />
      <ConfirmModal
        open={!!removing}
        onClose={() => setRemoving(null)}
        onConfirm={remove}
        title={t.removeTitle}
        message={removing ? fmt(t.removeBody, { label: savedLabel(removing, false).title }) : ""}
        confirmLabel={t.remove}
        danger
        loading={busy === "remove"}
      />
    </section>
  );
}

function AddNumberModal({ open, onClose, onAdded }: { open: boolean; onClose: () => void; onAdded: () => void }) {
  const t = useT().user.pay;
  const [phone, setPhone] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const normalized = normalizePhone(phone);
    if (!normalized) return setError(t.phoneInvalid);
    setSaving(true);
    try {
      await api.post("/me/payment-methods", { phone: normalized });
      toast.success(t.numberAdded);
      setPhone("");
      setError(null);
      onAdded();
    } catch (err) {
      if (err instanceof ApiError && err.errors?.phone) setError(err.errors.phone[0] ?? null);
      else toast.error(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title={t.addNumberTitle} size="sm">
      <form onSubmit={submit}>
        <PhoneField
          id="add-phone"
          value={phone}
          onChange={(v) => {
            setPhone(v);
            setError(null);
          }}
          error={error}
          hint={t.addNumberHint}
          autoFocus
        />
        <Button type="submit" size="lg" loading={saving} className="mt-5 w-full">
          {t.addNumberCta}
        </Button>
      </form>
    </Modal>
  );
}
