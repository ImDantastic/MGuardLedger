# Morthal Guard Command System

A Skyrim-themed guard management dashboard for the Hold of Hjaalmarch. This is a single-page web application that provides a complete operational command interface for managing a guard force.

## Features

- **Command Hall** — Dashboard with real-time stats, active guards, recent activity, open reports, and bounties
- **Guard Roster** — Full CRUD for guard records with badge numbers, ranks, watch assignments, pay rates, and status
- **Watch Posts** — Visual breakdown of Night Watch, Day Watch, and Evening Watch shifts
- **Guard Duties** — Task/order management with priority levels, assignments, and status tracking
- **Watch Log** — Activity log for patrols, incidents, watch relief, stand-downs, and alerts
- **Hold Reports** — Comprehensive incident reporting system with narrative, evidence, witnesses, and follow-up
- **Bounty Board** — Wanted persons tracker with full physical descriptions, threat levels, and crime details
- **Coin Ledger** — Payroll calculator supporting hourly, salary, weekly stipend, and daily rate pay types
- **Role-Based Auth** — Four access levels: Admin, High Command, Low Command, and Guard (plus guest view)
- **Audit Log** — Tracks all logins, record changes, exports, and deletions
- **Data Import/Export** — JSON export/import for full backups, CSV export for payroll

## Tech Stack

- Vanilla HTML, CSS, and JavaScript (no build tools or frameworks)
- All data stored in browser `localStorage`
- Session auth stored in `sessionStorage`
- Deployed as a static site on Netlify

## Running Locally

Open `index.html` directly in a browser, or use any static file server:

```bash
npx serve .
```

## Demo Credentials

The application ships with demo data and four role-based passphrases for authentication. Guest access (no login) provides read-only access to non-sensitive pages.
