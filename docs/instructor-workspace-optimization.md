# Instructor workspace optimization

## Beta feedback: direct module workflow

Course Content now shows directly clickable module cards. One click opens the module's authoring page; the expandable preview and second Manage module action were removed. Section Content uses the same direct module destination. Module authoring now places learning materials and assessments on one scrolling page with their existing creation, publication, AI, deletion and submission controls. Assessment-targeted links show the assessment section first; material-targeted links retain the existing focused-material ordering.

Course and section workspaces now share the tab order Content, Activities, Grades, Students. Section pages initially show Students because their primary purpose is roster management. Their tabs scroll on smaller screens and enlarged text. Course/section context and the existing authorization and publication operations remain in place.

## Completed: navigation foundation

- Six primary destinations: Dashboard, My Courses, Grading, Calendar, Insights, Messages.
- Mobile primary destinations: Dashboard, Courses, Grading, Messages. Calendar and Insights remain in More.
- Instructor account menu exposes Profile, theme preference, and the existing confirmed logout operation.
- Teaching AI is accessible from the workspace header and existing dashboard/course actions.
- Existing destination indexes are retained, including hidden Profile (4) and Teaching AI (6). The existing lazy IndexedStack retains opened page and conversation state during tab changes.
- Student and administrator navigation is unchanged.

## Next stages

1. Add validated, reusable course/section context across course tabs, assessment creation, grading and live-class entry. Revalidate ownership and active section status on changes; do not treat cached selection as authorization.
2. Consolidate course activity filters and counts, direct module actions, and section roster actions using existing services.
3. Add actionable dashboard attention items sourced from real authorized records.
4. Build a filtered submission review queue with next-submission navigation and unsaved-change handling around existing protected grading calls.
5. Streamline assessment settings and contextual AI entry points while preserving publication review.

The header shortcut currently opens the existing Teaching AI destination. It does not yet inject section, module, material, or assessment context, and does not add persisted instructor AI history.

## Phase 2: session course and section context

Implemented a lightweight session selection store in `lib/services/instructor_workspace_context.dart`. Existing authorized services validate course ownership and active section membership before a section is accepted. Revision tokens reject superseded selection requests; authentication changes and workspace disposal clear the store.

The course workspace now provides an All sections / active section selector. Section changes reload the relevant roster, invitation, assessment and submission data while retaining the mounted four-tab layout. Actions are blocked while switching. Section management validates and records opened sections; returning from section management or semester grading refreshes the parent workspace. Covered routes do not use preferences or introduce new database writes for navigation state.

Semester grading inherits the current course/section when opened from the main Grading page, validates it against authorized records, and synchronizes changes made with its existing selectors. Existing calculation, preview and posting operations remain authoritative. AI quiz publication reuses a remembered section only after checking the course's current active sections, and retains its final publication confirmation. Live-class entry uses the selected section and remembers a section chosen in its existing picker.

Validation: 257 focused/regression tests passed, including account changes, stale selection revisions, invalid/archived/deleted sections, inherited semester-grading context, responsive layouts and grading safeguards. Targeted instructor analysis passed. Full-project analysis reported only the two existing informational student-page parameter-name lints. Production account data and live grade posting were not exercised by these fixture-based tests.

Limits: selection persists within the signed-in app session, not across a browser reload. Course content remains shared across sections according to the existing schema. The general submission queue and assessment-level grading screen retain their existing scope; section-filtered queue review belongs to the next grading stage. No new section-assignment field was added to ordinary assessment creation. Existing section-scoped quiz publication remains supported. The selector reuses the existing authorized section service, which also loads section counts; query optimization can follow if profiling warrants it.

Final race check additionally covers failed older requests: they cannot clear a newer selection. The context and grading suites were rerun after this guard.

Files changed in Phase 2:
- `lib/services/instructor_workspace_context.dart`
- `lib/screens/instructor/instructor_main_page.dart`
- `lib/screens/instructor/instructor_class_details_page.dart`
- `lib/screens/instructor/instructor_course_sections_page.dart`
- `lib/screens/instructor/instructor_module_detail_page.dart`
- `lib/screens/instructor/instructor_semester_grades_page.dart`
- `test/instructor_workspace_context_test.dart`
- `test/instructor_deep_tasks_test.dart`
- This document.

Next priority: course-workspace actions and assessment filtering, then the unified grading queue. These supersede the earlier uncompleted context entry in the next-stages list.

## Backend boundaries

No schema, rules, policies, edge functions, authentication, grading calculations, or LiveKit permissions are changed by this stage. Calendar events remain temporary under the existing production configuration. Shared event persistence and any future persisted instructor assistant history require a separate backend design and authorized permissions rollout.
