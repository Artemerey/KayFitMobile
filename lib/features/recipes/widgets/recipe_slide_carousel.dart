import 'package:flutter/material.dart';

import '../../../shared/theme/kayfit2_theme.dart';
import '../models/recipe_detail.dart';
import '../utils/recipe_image_url.dart';

/// Swipeable carousel of a recipe's slides (hero → ingredients → steps → cta),
/// ordered by `order_idx`. Mirrors the Carousel Factory visual: full-bleed
/// image with the caption laid over a bottom gradient scrim.
///
/// Images load via plain [Image.network] (the project intentionally has no
/// `cached_network_image` dependency — decision #C); each slide gets a
/// progress placeholder and a graceful error tile.
class RecipeSlideCarousel extends StatefulWidget {
  const RecipeSlideCarousel({super.key, required this.slides});

  final List<RecipeSlide> slides;

  @override
  State<RecipeSlideCarousel> createState() => _RecipeSlideCarouselState();
}

class _RecipeSlideCarouselState extends State<RecipeSlideCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 5,
        child: ColoredBox(
          color: K2Colors.lightHairline,
          child: Center(
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: K2Colors.lightFgMute,
              size: 40,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _SlideView(slide: slides[i]),
            ),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 12),
          _Dots(count: slides.length, active: _page),
        ],
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final RecipeSlide slide;

  @override
  Widget build(BuildContext context) {
    final url = resolveRecipeImageUrl(slide.imageUrl);
    final caption = slide.caption?.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: K2Colors.lightHairline,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => const ColoredBox(
            color: K2Colors.lightHairline,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: K2Colors.lightFgMute,
                size: 36,
              ),
            ),
          ),
        ),
        if (caption != null && caption.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                ),
              ),
              child: Text(
                caption,
                style: const TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? K2Colors.accent : K2Colors.lightBorderStrong,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
