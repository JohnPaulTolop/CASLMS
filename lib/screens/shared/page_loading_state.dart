import 'package:flutter/material.dart';

/// Initial page loading has no temporary title, toolbar, or unavailable actions.
class PageLoadingState extends StatelessWidget {
  const PageLoadingState({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
