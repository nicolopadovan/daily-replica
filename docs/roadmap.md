# Daily Replica Product Roadmap

Daily Replica is a local-first macOS activity tracker: granular Screen Time for
work, projects, apps, websites, and categories. The product should optimize for
trustworthy time data before richer reporting.

## Recommended Roadmap

1. **Tracking Engine v2**
   - Improve precision from timer-only sampling to event-aware tracking.
   - Record app/window/project changes at second-level granularity.
   - Handle idle, sleep/wake, screen lock, app quit, and permission-denied states.

2. **Timeline Editing**
   - Split and merge activity segments.
   - Change category or project for a selected range.
   - Make corrections fast enough that users trust the final day view.

3. **Project Session Model**
   - Treat "What are you working on?" as a first-class active project session.
   - Track project start/end separately from app activity.
   - Attribute app and website time to the active project automatically.

4. **Screen Time Dashboard**
   - Add day, week, and month summaries.
   - Show time by category, project, app, and website.
   - Highlight focused work, distractions, and uncategorized time.

5. **Classification UX**
   - Improve the rules editor.
   - Suggest rules from repeated corrections.
   - Add bulk classification for uncategorized apps and hosts.

6. **Privacy And OSS Hardening**
   - Add local data reset/delete controls.
   - Add CSV/JSON export.
   - Add clearer permission explanations.

## Next Milestone: Tracking Engine v2

### Goal

Make Daily Replica's timeline accurate enough that users trust it as the source
of truth for personal Screen Time and project time. The app should capture
activity changes within seconds, while staying local-first and understandable.

### Why This Comes First

Dashboards, reports, and project summaries are only useful if the underlying
segments are accurate. Better charts on weak data would make the app look more
complete while hiding the real risk: users cannot rely on the timeline.

### User-Facing Behavior

- When the frontmost app changes, the current segment ends and a new one starts.
- When the active window title or Chrome URL changes, the current segment ends
  if the identity materially changed.
- When the Mac becomes idle, the active segment ends and an inactive segment
  begins.
- When the user returns from idle, sleep, or screen lock, a new active segment
  begins from the return time.
- When the active project changes, later app activity is attributed to the new
  project without rewriting past segments.
- Permission limitations are visible: if window titles or Chrome URLs cannot be
  read, the app still tracks app-level activity and marks detail as unavailable.

### Technical Direction

Use a hybrid tracker:

- **Event observers** for macOS app activation, workspace sleep/wake, screen
  lock/unlock, and session activity where available.
- **Short heartbeat sampling** for details that do not reliably emit events,
  such as focused window title, Chrome URL, idle duration, and segment end-time
  freshness.
- **Segment reducer rules** remain in `DailyReplicaCore`, so the app target only
  supplies observations and persistence orchestration.

This avoids a custom event system for everything while improving precision where
macOS already provides good signals.

### Data Model Needs

The current `ActivitySegment` model can carry the first version. It already has
start/end, app identity, window title, URL, category, project, and manual edits.
Tracking Engine v2 should avoid a schema migration unless implementation proves
one is necessary.

Potential later additions:

- observation source, such as event or heartbeat
- confidence/detail level, such as app-only versus app plus window/URL
- explicit idle reason, such as idle timer, sleep, or lock

These should not be added until the UI or debugging workflow needs them.

### Acceptance Criteria

- App changes create separate segments without waiting for the next long timer.
- Idle transitions are represented as inactive time, not merged into the last
  active app.
- Sleep/wake does not create misleading active time across the sleep interval.
- Project changes only affect future activity.
- App-level tracking continues when Accessibility or Automation permission is
  unavailable.
- Existing manual edits remain protected from automatic merging.
- Existing `swift test` coverage stays green, with new reducer/service tests for
  event-driven tracking cases.

### Open Product Decision

The next design choice is precision versus permission minimization:

- **Maximum precision:** use every reasonable macOS signal, even if that means
  clearer permission requests and more system integrations.
- **Minimal permissions:** keep tracking mostly app-level and accept less exact
  window/website/project attribution.

Recommendation: choose maximum precision, but degrade gracefully when a user
declines a permission.
