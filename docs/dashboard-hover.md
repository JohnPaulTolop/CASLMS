# Dashboard hover feedback

Admin, Instructor and Student dashboards share `DashboardHover`. Cards lift
slightly, shadows soften and an accent border appears on pointer hover or when
an existing child control receives keyboard focus. Navigation items and buttons
use smaller lifts. Large admin panels use a shadow without movement.

The wrapper owns no taps, creates no additional keyboard stop, and preserves
child cursors. Informational cards keep a normal cursor. Existing navigation,
authentication, Firestore queries and live subscriptions stay in their existing
widgets. Reduced-motion preferences disable the translation and animation;
focus and border feedback still appear instantly.

## Files

- `lib/screens/shared/dashboard_hover.dart`: reusable hover/focus decoration.
- `lib/screens/student/student_dashboard_page.dart`: welcome, summaries, class
  rows, upcoming cards, profile, notification bell and dashboard buttons.
- `lib/screens/instructor/instructor_dashboard_page.dart`: welcome, summaries,
  quick actions, course cards, bell and dashboard buttons.
- `lib/screens/admin/admin_dashboard_page.dart`: metrics, attention/file/log
  rows, panels, bell and dashboard actions.
- `lib/screens/admin/admin_main_page.dart`: sidebar and compact-menu items.
- `lib/screens/shared/role_navigation_bar.dart`: student/instructor navigation
  and More cards; existing selection animations also honor reduced motion.

## Verification

Static analysis passed for all six Dart files. Browser verification is still
required; automated Edge cannot start in the restricted development runtime.

After rebuilding, hover cards and controls in each role, then use Tab/Enter to
verify focus and existing navigation. Check narrow layouts and system reduced
motion. Informational cards should animate without gaining a click action.

```powershell
cd C:\caslms-main
& {
    $ErrorActionPreference = 'Stop'
    .\scripts\build-vercel.ps1
    npx.cmd vercel deploy --prebuilt
}
```
