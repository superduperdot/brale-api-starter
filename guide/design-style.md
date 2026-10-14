# Design

Two visual systems have shipped on Brale apps. Pick by audience. Do not blend them in one product.

| | Operator command center | End-user treasury or wallet |
|--|-------------------------|-----------------------------|
| Audience | People who live in the data | People who want one balance and a send button |
| Money | Dollar total first; assets second | One preferred balance; rails are a detail |
| Labels | Value Layer grammar on every row | Plain words: USDC, Base, wire |
| CSS | Tailwind | Tailwind, or CSS modules with a short token list |
| Charts | D3 for the command center | Few charts. Status is a color and a word. |

Typography: Geist, self-hosted, if you set a content-security policy. A font CDN will fail `font-src 'self'`.

Layout range worth testing: 320px through a wide monitor. A command center that only works at 1440px will be used on a laptop anyway.

## Patterns worth copying

| Pattern | Use it in | What it is |
|---------|-----------|------------|
| Recipient first | Operations dashboard | Choose the person, then the payment method, then the amount |
| Stale-while-revalidate balances | Self-custody wallet | Paint the cached balance, refresh behind it |
| White-label tokens | Analytics, compliance | Name, logo, and accent from config, not from a fork |
| Command center | Analytics | One KPI row, charts, a live feed |
| Side panel | Extension wallet | The default surface is the browser side panel; a popup is the alternate |

Chain and token metadata — `display_name`, `logo_url`, `explorer_url`, `decimals` — comes from the open [Brale Network API](https://brale.network/api) (`/transfer-type/:id`, `/value-type/:id`). Prefer it over a hand-maintained map. If you self-host or proxy those logo assets, account for them in your content-security policy rather than hotlinking a CDN you did not review.

`logo_url` and `explorer_url` on the Brale Network API (`/value-type/:id`, `/transfer-type/:id`) are confirmed present (verified against `brale.network/api/openapi.json`, 2026-10-14). Prefer the registry over a hand-maintained chain-meta map.

For real-time feeds, define stale-attention thresholds per rail — wire and ACH transfers settle slower than on-chain, so a wire row that has been 'pending' for 2 hours is normal, while an on-chain transfer pending for 10 minutes is worth highlighting. Store the thresholds in config, not as magic numbers in the component.

## CSS modules, when Tailwind is the wrong weight

A restrained product (a treasury portal, a card program) can use CSS modules and custom properties instead of a utility framework. The constraint is the token list, not class discipline.

```css
:root {
  --ink: #1a1a1a;
  --muted: #8a8a8a;
  --signal: #e05a00;
  --elev-01: #f5f5f5;
  --line: #e0e0e0;
  --font-mono: "SF Mono", "Fira Code", monospace;
  --space-2: 4px;
  --space-3: 8px;
  --space-4: 12px;
  --control-height: 40px;
}
```

```css
.input { height: var(--control-height); border: 1px solid var(--line); }
.select { composes: input; appearance: none; }
```

Rules that pair with this system:

- 14px minimum
- One accent (`--signal`), used rarely
- Depth from lightness, not from drop shadows
- Square corners, if you want the industrial end of this look. If you need rounded controls, decide that once, in the tokens.

## Related

- [value-layer.md](value-layer.md)
- [csf-gsf.md](csf-gsf.md)
- [concepts.md](concepts.md)
