# Costs

**All figures are estimates** from public price lists (checked 2026-11-15) and exclude VAT. Confirm on each provider's pricing page before approving. The admin Infrastructure page labels each figure as live usage, estimate, or billed amount.

## Monthly estimate

| Item | Estimate | Notes |
|---|---|---|
| Hetzner Cloud server, 4 vCPU / 8 GB / 80 GB (CX33 class, formerly CX32) | EUR 7 to 9 | Billed hourly up to a monthly cap. A stopped server is still billed; only deleting it stops billing. |
| Hetzner automatic backups | +20% of the server, about EUR 1.5 to 2 | 7 daily snapshots. |
| Primary IPv4 | about EUR 0.5 | |
| Vercel Pro | US$20 per team member | Free Hobby plan does not allow commercial use. US$0 if the website were moved to the Hetzner server instead. |
| Cloudflare DNS, proxy, TLS, basic WAF | US$0 | Free plan. |
| Cloudflare R2 | US$0 up to 10 GB, then about US$0.015 per GB-month | No egress fees. Operations have free monthly allowances. A payment method is required to enable R2. |
| Database backups in R2 | Included above | Compressed dumps are small (MBs). |
| Bunny Stream | Usage based | Storage per GB per region and delivery per GB (Africa priced higher than Europe). Encoding included. |
| GitHub Actions | US$0 within the free minutes of a private repo | The Flutter and image build jobs use the most minutes. |
| Let's Encrypt, Netdata, Docker | US$0 | |
| **Total excluding Bunny** | **about US$30 to 35 with Vercel Pro; about US$10 to 13 without** | |

## What can be capped, and what cannot

| Provider | Can it be hard-capped? | What to set up |
|---|---|---|
| Hetzner | Yes, effectively | The server size fixes the price. Avoid adding volumes, extra IPs or load balancers without a decision. |
| Vercel Pro | Yes | Settings > Billing > Spend Management: set a limit and choose to pause projects when it is reached (the site goes down at the limit, so set it with headroom). |
| Cloudflare R2 | No hard cap | Billing notifications; usage is visible on the admin Infrastructure page. Costs are small for images. |
| Bunny | No hard cap | Prepaid balance: low-balance email alerts, optional auto-recharge. If the balance reaches zero, streaming stops. Watch monthly bandwidth on the Infrastructure page. |
| Cloudflare free plan | Nothing to cap | Paid add-ons (Argo, extra WAF, Images) stay off. |

The Infrastructure page and budget emails (50, 75, 90, 100% of `INFRA_MONTHLY_BUDGET_USD`) **report** spend; they do not stop it.

## Ways to save if needed

* Run the website on the Hetzner server instead of Vercel (saves about US$20 per month, adds ops work).
* Turn off Hetzner backups and rely on database dumps plus the repo (saves about EUR 2; slower full-server recovery).
* Bunny: one storage region only; lower default playback quality for mobile networks.
