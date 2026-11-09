# Module section assignment: backend dependency

Current production model: modules and module resources belong to a course. Assessment `sectionId` is either empty (course-wide) or one active section. The instructor module page now identifies its viewing section and filters assessment cards accordingly. Materials remain clearly marked as shared across all sections. Teaching AI uses consistent 22px insets inside its existing 960px column.

The requested one-or-multiple-section module assignment is not implemented as a cosmetic chooser: it would misrepresent what students can access. It requires approval for a saved assignment field and matching backend permission/query changes. No rules, schema, policies or edge functions were modified in this update.

Recommended next implementation:
1. Store an explicit selected section ID list on each module, validated against active sections owned by the same instructor/course. Define legacy unassigned modules as shared across all sections.
2. Make materials inherit the module audience. Label shared content and show the module's selected section names at authoring time.
3. Define how assessment audiences interact with module audiences; existing single-section assessments cannot represent a multi-section restricted audience without a backend change.
4. Enforce audience membership in student reads, submissions, AI source access, notifications, and backend assessment publication. UI filters alone are not access restrictions.
5. Add multi-select choices before module creation, defaulting to the validated current section. Let the instructor select multiple active sections or explicitly all sections.
6. Test cross-section access, archived sections, legacy modules, shared content, and publication before enabling the chooser.

Do not copy the same module per section: separate copies would drift and duplicate material and assessment maintenance.
