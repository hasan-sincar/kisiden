import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double tabletMaxWidth;
  final double desktopMaxWidth;
  final Color outerBackgroundColor;
  final double borderRadius;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.tabletMaxWidth = 800,
    this.desktopMaxWidth = 1000,
    this.outerBackgroundColor = const Color(0xFFEEEEEE),
    this.borderRadius = 16,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1100;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isDesktopLayout = screenWidth >= 1100;
    final bool isTabletLayout = screenWidth >= 650 && screenWidth < 1100;

    final bool useFramedLayout = isDesktopLayout || isTabletLayout;
    final double maxWidth = isDesktopLayout
        ? desktopMaxWidth
        : (isTabletLayout ? tabletMaxWidth : double.infinity);

    return ColoredBox(
      color: useFramedLayout ? outerBackgroundColor : Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: useFramedLayout
                  ? const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                useFramedLayout ? borderRadius : 0,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
