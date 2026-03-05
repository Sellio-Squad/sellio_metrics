## 🏛️ Domain & Metrics Model

This page explains how **pull request metrics** flow from GitHub → backend → frontend, and how the domain model is structured to support KPIs, bottlenecks, leaderboards, and timelines.

---

### 1. Backend `PrMetric` (Source of Truth)

The backend defines the canonical PR metric type in `backend/src/core/types.ts` as `PrMetric`. It is a GitHub‑agnostic domain object with fields such as:

- **Core identity & metadata**
  - `pr_number`, `url`, `title`
  - `head_ref`, `base_ref`
  - `creator: UserInfo`
  - `assignees: UserInfo[]`
- **Comments & approvals**
  - `comments: CommentGroup[]`
    - Groups comments by author with:
      - `first_comment_at`, `last_comment_at`, `count`
  - `approvals: Approval[]`
    - Each approval has `reviewer`, `submitted_at`, `commit_id`, optional `note`.
  - `review_requests: string[]` (requested reviewers’ logins)
- **Timing & status**
  - `opened_at`, `closed_at`, `merged_at`
  - `first_approved_at`
  - `time_to_first_approval_minutes`
  - `required_approvals_met_at`
  - `time_to_required_approvals_minutes`
  - `status: "pending" | "approved" | "merged" | "closed"`
  - `week` (ISO week bucket, e.g. `2026-W07`)
- **Labels & diff stats**
  - `labels: string[]`
  - `milestone` (title + number, if present)
  - `draft: boolean`
  - `files_changed: string[]` (reserved for richer diff views)
  - `diff_stats: { additions, deletions, changed_files }`

#### 1.1 Mapping GitHub → `PrMetric`

All transformation logic is in `backend/src/modules/metrics/metrics.mapper.ts`:

- `toUserInfo(GitHubUser)`:
  - Normalizes logins, IDs, URLs, and avatar URLs.
- `groupComments(issueComments, reviewComments)`:
  - Merges issue comments and review comments.
  - Excludes bot comments.
  - Produces `CommentGroup[]` with per‑author first/last timestamps and count.
- `processApprovals(reviews, headSha)`:
  - Filters only `APPROVED` reviews.
  - Deduplicates by reviewer (keeps latest approval per reviewer).
  - Prefers approvals for the current head commit (fallback to any approval).
  - Sorts approvals chronologically.
- `determinePrStatus(mergedAt, closedAt, requiredApprovalsMet)`:
  - Derives PR status:
    - `merged` if `mergedAt` is set.
    - `closed` if `closedAt` is set and not merged.
    - `approved` if required approvals are met on an open PR.
    - `pending` otherwise.
- `mapToPrMetric(input)`:
  - Combines all of the above:
    - Computes `first_approved_at`, `time_to_first_approval_minutes`.
    - Uses `requiredApprovals` (from env) to compute:
      - When required approvals were met.
      - `time_to_required_approvals_minutes`.
    - Computes `week` via `toISOWeek(pr.created_at)`.
    - Assembles labels, milestone, diff stats, review requests, and derived fields.

This mapping is **pure** and side‑effect free; services handle API calls and caching.

---

### 2. Frontend `PrEntity` (Rich Client‑Side Model)

On the frontend, `PrMetric` JSON is deserialized into `PrEntity` (in `frontend/lib/domain/entities/pr_entity.dart`), which:

- Converts strings to strong Dart types (`DateTime`, value objects).
- Adds convenience methods and computed properties for the UI:
  - `bool get isOpen` (no `mergedAt` and no `closedAt`).
  - `bool get isMerged` (status is `merged`).
  - `int get totalComments` (sums counts from `CommentEntity` groups).
  - `String get repoName` (best‑effort extraction from the PR URL).
- Exposes a `timeline` extension:
  - Produces a chronologically ordered list of `PrTimelineEvent`:
    - `created` (PR opened).
    - `approved` (each approval, with commit info).
    - `commented` (first and last comment per participant).
    - `merged` or `closed`.
- Exposes a `participants` list:
  - Unique `UserEntity` instances across creator, assignees, approvers, commenters, and merger.

Other domain entities (`BottleneckEntity`, `KpiEntity`, `LeaderboardEntry`, etc.) are composed from one or more `PrEntity` objects.

---

### 3. Bottlenecks

Bottlenecks represent PRs that have been **open for too long** relative to a configurable threshold.

- Implemented in `frontend/lib/domain/services/bottleneck_service.dart`.
- Input:
  - `List<PrEntity> prData`
  - `thresholdHours` (default from `BottleneckConfig.defaultThresholdHours`).
- Process:
  1. Filter **open** PRs (`pr.isOpen`).
  2. For each PR:
     - Compute `waitHours` from `openedAt` to `DateTime.now()`.
     - Compute `waitDays = waitHours / 24`.
     - Classify severity via `_classifySeverity(waitHours, thresholdHours)`:
       - Uses `severityHighMultiplier` / `severityMediumMultiplier` constants.
  3. Build `BottleneckEntity`:
     - `prNumber`, `title`, `url`, `author`, `waitTimeHours`, `waitTimeDays`, `severity`.
  4. Filter out entries below the threshold.
  5. Sort descending by `waitTimeHours`.
  6. Take the top `maxDisplayCount` entries.

`DashboardProvider.bottlenecks` simply delegates to this service, passing the currently filtered set of PRs and the configured threshold. Severity is rendered via `severity_presentation.dart`.

---

### 4. KPIs & Spotlight Metrics

High‑level KPIs and spotlight metrics are computed in `KpiService` (`frontend/lib/domain/services/kpi_service.dart`):

- **Inputs**:
  - A filtered list of `PrEntity` (`weekFilteredPrs`).
  - Optional developer filter (to focus on a single engineer).
- **Outputs** (`KpiEntity`, `SpotlightEntity`, etc.):
  - Throughput metrics:
    - Number of PRs merged / closed over a period.
    - PRs opened per week (`week` bucket).
  - Velocity metrics:
    - Average/median `timeToFirstApprovalMinutes`.
    - Average/median `timeToRequiredApprovalsMinutes`.
    - Time‑to‑merge distributions.
  - Quality/collaboration metrics:
    - Comment volume per PR.
    - Approvals per PR.
    - Ratio of approved vs. pending PRs.
  - Spotlight metrics (examples):
    - Top contributors by merged PR count.
    - Fastest reviewers (by average approval response time).
    - PRs with unusually high diff stats or review/comment activity.

The exact shape of `KpiEntity` and `SpotlightEntity` can be inspected in `frontend/lib/domain/entities/kpi_entity.dart` and related files, but the core idea is that **all raw timing and volume data comes from `PrEntity`**, which in turn comes from the backend’s `PrMetric`.

---

### 5. Leaderboard

Leaderboard data can be computed **server‑side** or **client‑side**:

- Backend type: `LeaderboardEntry` in `backend/src/core/types.ts`.
  - Fields: `developer`, `avatarUrl`, `prsCreated`, `prsMerged`, `reviewsGiven`, `commentsGiven`, `totalScore`.
- Frontend type: `LeaderboardEntry` in `frontend/lib/domain/entities/leaderboard_entry.dart` (mirrors the backend).

Flow:

1. `DashboardProvider._updateLeaderboard()` calls:
   - `_repository.calculateLeaderboard(weekFilteredPrs);`
2. The `MetricsRepositoryImpl` typically will:
   - Either:
     - Call a backend endpoint (e.g. `POST /api/metrics/leaderboard`) with the current PR data, or
   - Or:
     - Implement the leaderboard algorithm client‑side using the same `PrEntity` list.
3. `DashboardProvider` stores the result and exposes `leaderboard` to widgets.

Widgets such as `leaderboard_page.dart`, `leaderboard_section.dart`, and `leaderboard_row.dart` use these entries to display ranked team members with scores and component breakdowns.

---

### 6. Filtering & Segmentation

Filtering is centralized in `FilterService` (`frontend/lib/domain/services/filter_service.dart`) and orchestrated by `DashboardProvider`:

- Filters:
  - **Date range**: `setDateRange(start, end)` on `DashboardProvider`:
    - Uses `FilterService.filterByDateRange` to keep only PRs within the given dates.
  - **Week**: `weekFilter`:
    - Uses `FilterService.filterByWeek` to narrow to the selected weekly bucket.
  - **Status**: `statusFilter`:
    - Filters for open/merged/closed/pending PRs for list views.
  - **Search**: `searchTerm`:
    - Filters by title or other string fields.
  - **Developer**: `developerFilter`:
    - Used by `KpiService` and other analytics to focus on a single developer.

This separation keeps the dashboard widgets simple—most of them just consume `DashboardProvider` getters and render the resulting entities.

---

### 7. End‑to‑End Metrics Flow Summary

1. **GitHub → Backend**
   - Backend fetches raw PRs, reviews, and comments via `CachedGitHubClient` + `GitHubClient`.
   - `metrics.mapper.ts` transforms raw data into a normalized `PrMetric` list.
   - Results are cached (resource‑level and result‑level) in Workers KV.

2. **Backend → Frontend**
   - Flutter app calls `GET /api/metrics/:owner/:repo`.
   - Receives a JSON payload containing `PrMetric[]`.

3. **Frontend Data Layer**
   - `RemoteDataSource` fetches JSON.
   - `PrModel` (and other DTOs) parse JSON into `PrEntity` and related entities.

4. **Frontend Domain Layer**
   - `DashboardProvider` stores `PrEntity` list.
   - `FilterService`, `KpiService`, `BottleneckService`, and repository methods derive:
     - KPIs, spotlight metrics, bottlenecks, leaderboards, charts, and timelines.

5. **Presentation Layer**
   - Widgets read from `DashboardProvider` and render:
     - KPI cards, spotlight cards, bottleneck lists, open PR tables, charts, and team leaderboards.

If you need to add a new metric or visualization, you typically:

1. Extend `PrMetric` / `PrEntity` (if new raw data is required).
2. Update `metrics.mapper.ts` + `PrModel` to populate the new field.
3. Add computations to `KpiService` or a new domain service as needed.
4. Expose the result via `DashboardProvider`.
5. Render it in a new or existing widget. 

