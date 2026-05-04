// Kayfit 2.0 preview screen — wires the new design tokens + KayfitRings widget
// onto a real route so the look can be validated on simulator/device before
// the full redesign lands.
//
// Settings → AI Data Processing-style entry → /kayfit2/preview.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/widgets/kayfit_rings.dart';

class Kayfit2PreviewScreen extends StatefulWidget {
  const Kayfit2PreviewScreen({super.key});

  @override
  State<Kayfit2PreviewScreen> createState() => _Kayfit2PreviewScreenState();
}

class _Kayfit2PreviewScreenState extends State<Kayfit2PreviewScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final t = _dark ? K2Theme.dark : K2Theme.light;

    final values = const KayfitRingsValues(
      kcal: 1450, kcalGoal: 2100,
      protein: 65, proteinGoal: 130,
      carbs: 180, carbsGoal: 250,
      fat: 30, fatGoal: 70,
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar: back + title + theme toggle ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: t.fg, size: 20),
                    onPressed: () => context.pop(),
                    splashRadius: 22,
                  ),
                  const Spacer(),
                  Text(
                    'KAYFIT 2.0 · PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: t.fgDim,
                      fontFamily: K2Fonts.sans,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _dark,
                    onChanged: (v) => setState(() => _dark = v),
                    activeColor: K2Colors.accent,
                  ),
                ],
              ),
            ),

            Container(height: 1, color: t.hairline),

            // ── Hero rings card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: KayfitRingsSummary(values: values, theme: t),
            ),

            Container(height: 1, color: t.hairline),

            // ── Notes ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('what this shows', t),
                    const SizedBox(height: 8),
                    _Body(
                      'Foundation widget KF2-FOUND-1: Apple Activity 4-ring '
                      'summary. Outer → inner: kcal · protein · carbs · fat. '
                      'Each ring is a CustomPainter arc with a linear-gradient '
                      'shader matching the JSX prototype.',
                      t,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('next foundation tickets', t),
                    const SizedBox(height: 8),
                    _Bullet('KF2-FOUND-2 · Calendar strip + month grid', t),
                    _Bullet('KF2-FOUND-3 · Tab bar Apple-style with center +', t),
                    _Bullet('KF2-FOUND-4 · Meal photo placeholder + meal row', t),
                    _Bullet('KF2-JOURNAL · JournalV2 screen (assemble)', t),
                    _Bullet('KF2-CHAT · ChatV2 screen + thinking bubble', t),
                    const SizedBox(height: 20),
                    _SectionLabel('design source', t),
                    const SizedBox(height: 8),
                    _Body(
                      'specs/kayfit_2.0/HLD_kayfit_2.0_redesign.md\n'
                      'specs/kayfit_2.0/source_handoff/project/Kayfit 2.0.html',
                      t,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.t);
  final String text;
  final K2Theme t;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: t.fgDim,
        fontFamily: K2Fonts.sans,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, this.t);
  final String text;
  final K2Theme t;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: t.fg,
        fontFamily: K2Fonts.sans,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, this.t);
  final String text;
  final K2Theme t;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 10),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: t.fgMute,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: t.fg,
                fontFamily: K2Fonts.mono,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
