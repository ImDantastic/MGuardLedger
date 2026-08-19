# AGENTS.md — Morthal Guard Command System

## Architecture

This is a static, single-page application contained entirely in `index.html`. There are no build steps, no dependencies, and no server-side components.

### Key Files

- `index.html` — The entire application: HTML structure, CSS styles, and JavaScript logic
- `netlify.toml` — Netlify deployment configuration (publish directory and security headers)
- `.gitignore` — Excludes node_modules and .netlify directories

### Application Structure (within index.html)

The file is organized in this order:

1. **CSS (~257 lines)** — Custom properties, layout, components, modals, responsive breakpoints
2. **HTML (~620 lines)** — Sidebar navigation, page sections (dashboard, roster, watch, duties, activity, reports, bounty board, payroll, settings, users, audit), modals for CRUD operations, login modal
3. **JavaScript (~1080 lines)** — Auth system, state management, CRUD operations, rendering functions, demo data seeding

### Data Model

All state lives in a single `D` object persisted to `localStorage` under key `mgcs_v2`:

- `D.guards[]` — Guard records (badge, name, rank, watch, status, pay)
- `D.tasks[]` — Duty/order assignments
- `D.activities[]` — Watch log entries
- `D.reports[]` — Incident/hold reports (comprehensive fields)
- `D.wanted[]` — Bounty board entries
- `D.auditLog[]` — System audit trail (capped at 2000 entries)
- `D.settings{}` — Hold configuration (org name, badge prefix, counters)

### Auth System

Role-based access with four tiers. Passphrases are hashed client-side using a simple DJB2 hash. Session state is in `sessionStorage`. Guest access (no login) provides read-only views of non-sensitive pages.

### Conventions

- No external dependencies or build tools
- All rendering is done via innerHTML with template literals
- IDs use `Date.now().toString(36) + random` for uniqueness
- Helper functions: `gv(id)` gets input value, `sv(id, val)` sets it, `fdt()` formats datetime, `fd()` formats date
- Badge/pill helpers: `wPill()`, `sBadge()`, `priBadge()`, `actBadge()`, etc.
- Navigation via `nav(pageName)` which shows/hides `.page` elements

### Deployment

Static site on Netlify. The publish directory is the repo root (`.`). No build command needed.
