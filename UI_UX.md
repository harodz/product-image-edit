# UI/UX Design Document — Product Image Edit

## Overview

A macOS desktop application that automates batch conversion of casual product photos into professional white-background shots using the Gemini image API. Users configure a job, watch it run with live per-image feedback, then review and export results — all without touching a terminal.

---

## Core User Journey

```
[Launch App]
     |
     v
[Pipeline Settings]  ──configure input, output, key settings──>  [API Settings]
     |
     | (click Run)
     v
[Batch Dashboard]  ──live progress, per-image status──>  [Failure Side Panel]
     |
     | (job complete)
     v
[Finality Overlay]  ──summary + CTA──>  [Output Review Gallery]
     |
     | (start new batch)
     v
[Pipeline Settings]  (cycle repeats)
```

---

## Screens

### 1. Pipeline Settings (`/`)

**Purpose:** Entry point. Users configure the job before running it.

**Key elements:**

| Element | Behavior |
|---|---|
| Input field (folder/file) | Drag-and-drop, Browse Folder, or Select Image(s). Single images and multi-file selections are auto-staged into a temp directory. |
| Output directory field | Text input. Required before run. |
| Edit prompt | Pre-filled with default: *"Clean it up and remove customer logo for a product shot. White background only. Professional Lighting."* |
| Model selector | Nano Banana 2 (default) vs Nano Banana |
| Workers slider | Default 10; guidance shown for rate-limit tiers |
| Max retries | Default 6 |
| Advanced toggles | Keep Raw, Fail Fast, Use Response Modalities, Copy Failed, No Progress |
| Command preview | Read-only shell preview of what will run — **never** shows the API key |
| Run button | Validates form, then navigates to Batch Dashboard |

**Validation:** Inline errors for missing/invalid input dir, missing output dir, workers < 1.

---

### 2. API Settings (`/api`)

**Purpose:** Manage the Gemini API key without exposing it in logs or previews.

**Key elements:**

| Element | Behavior |
|---|---|
| API key field | Obscured (password field). Pre-filled from `.env` in dev; saved to app-support `.env` in release. |
| App support path | Displayed so users know exactly where the key is stored |
| Save button | Writes key to app-support `.env` |

**Security note:** The key never appears in the command preview, activity logs, or any exported artifact. Log lines matching `GEMINI_API_KEY=…` / `GOOGLE_API_KEY=…` are redacted.

---

### 3. Batch Dashboard (`/batch-dashboard`)

**Purpose:** Live job monitoring. The most information-dense screen.

**Layout (top to bottom):**

```
┌──────────────────────────────────────────────────────────┐
│  Global Status Header                                     │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Dual-stage progress bar                             │ │
│  │  [████████ Gemini API ████][████ Cleanup ████]      │ │
│  │  Heartbeat dot · N active workers                   │ │
│  │  [ETA tile] [Images/min tile] [Success rate tile]   │ │
│  └─────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│  Processing Grid (scrollable table)                       │
│  [thumb] filename  [Gemini icon] [Cleanup icon] latency  │
│  [thumb] filename  [Gemini icon] [Cleanup icon] latency  │
│  ...                                                      │
├────────────────────────────┬─────────────────────────────┤
│  Collapsible Console       │  Failure Side Panel          │
│  (critical events only)    │  (slides in on any failure)  │
│  RETRYING / 429 / Error    │  Grouped by error type       │
│                            │  [Retry All] [Open Output]   │
│                            │  Workers slider              │
└────────────────────────────┴─────────────────────────────┘
```

**Global Status Header:**
- **Dual-stage progress bar:** purple segment = images at Gemini API stage; teal segment = images in cleanup (logo removal). Active counts displayed next to bar.
- **Heartbeat monitor:** pulsing dot shows active worker count. Turns amber with a countdown timer when a 429 rate-limit backoff is in progress.
- **Metric tiles:** ETA (based on current throughput), images/min, success %.

**Processing Grid:**
- One row per image
- 40×40 thumbnail (hover to expand to full-size preview)
- Gemini stage icon: spinning sparkle → green check or red error
- Cleanup stage icon: pending → processing → done
- Per-image latency (ms)
- Action buttons: **View Logs**, **Retry**

**Failure Side Panel:**
- Slides in from the right when any image fails
- Groups failures by type: Safety Filter / Rate Limit / API Error with counts
- Actions: **Retry All**, **Open Output Folder**, live **Workers** slider

**Collapsible Console:**
- Drawer at the bottom-left
- Filtered to critical events only: `RETRYING`, `429`, `Error:`, `Backoff`
- Full logs available via View Logs per image

**Finality Overlay** (on 100% completion):
- Full-screen modal: total image count, elapsed time, space saved
- CTA buttons: **Open Output Folder**, **Start New Batch**

---

### 4. Output Review Gallery (`/output-review`)

**Purpose:** Browse finished images before final export or delivery.

**Key elements:**

| Element | Behavior |
|---|---|
| Image grid | Auto-refreshes every ~4 s while pipeline is running |
| Per-image status | Approved / Needs Edit / Rejected / Unreviewed |
| Open Output Folder | Quick access to filesystem location |

---

## Navigation & Shell

**App Shell** wraps all screens with:
- Sidebar or top-nav tabs: Pipeline Settings · API Settings · (during/after run) Batch Dashboard · Output Gallery
- Breadcrumb / back affordance where appropriate

**Route map:**

| Route | Screen |
|---|---|
| `/` | Pipeline Settings |
| `/api` | API Settings |
| `/batch-dashboard` | Batch Dashboard |
| `/output-review` | Output Review Gallery |

---

## State Model (high-level)

```
AppState
├── PipelineConfig       # form values (input/output dir, prompt, flags)
├── PipelineRunSnapshot  # read-only view of live run
│   ├── phase            # idle | running | success | failed
│   ├── imageJobs[]      # per-image: GeminiStage, CleanupStage, latency, error
│   ├── throughputIPM    # images per minute
│   ├── eta              # estimated completion
│   ├── successRate      # 0.0–1.0
│   ├── is429Backoff     # rate-limit pause in effect
│   ├── backoffSecondsRemaining
│   └── spaceSavedBytes  # computed at completion
└── reviewItems[]        # output images with ReviewStatus
```

**Image job lifecycle:**

```
pending → [Gemini API call] → processing → done ──► [Logo removal] → cleanup done
                                         ↘ failed (Safety / Rate Limit / API Error)
```

---

## Key UX Principles

1. **Progressive disclosure** — advanced pipeline flags are collapsed by default; users can expand them when needed.
2. **Non-destructive** — source images are never modified. Output always goes to a separate directory.
3. **Resilient by default** — 429/503 retries happen automatically with visible backoff feedback; users can adjust workers without restarting.
4. **Security first** — API key is always obscured; command preview and logs never contain credentials.
5. **Live feedback** — the gallery and processing grid update in real time so users know exactly which images are done without waiting for the full batch.
6. **Graceful recovery** — failures are grouped, counted, and retry-able in one click; failed images can also be copied to a separate folder for a focused re-run.
