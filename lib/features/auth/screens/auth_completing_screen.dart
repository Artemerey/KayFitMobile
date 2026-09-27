import 'package:flutter/material.dart';

import '../../../shared/widgets/loading_indicator.dart';

/// Neutral parking screen used while an auth handoff is still transactional.
/// Router guards keep every login method here until the coordinator commits.
class AuthCompletingScreen extends StatelessWidget {
  const AuthCompletingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: LoadingIndicator()));
}
