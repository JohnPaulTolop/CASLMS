import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Loading hides temporary chrome and restores the page dark $dark',
      (t) async {
        var loading = true;
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return InstructorTaskScaffold(
                  title: 'Module',
                  subtitle: 'Course',
                  loading: loading,
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () {},
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                  footer: const Text('Publish'),
                  body: ListView(children: const [Text('Materials')]),
                );
              },
            ),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.text('Module'), findsNothing);
        expect(find.text('Publish'), findsNothing);
        expect(find.byTooltip('Back'), findsNothing);
        final spinner = t.getCenter(find.byType(CircularProgressIndicator));
        expect(spinner, t.getCenter(find.byType(Scaffold)));
        update(() => loading = false);
        await t.pumpAndSettle();
        expect(find.text('Module'), findsOneWidget);
        expect(find.text('Materials'), findsOneWidget);
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
