import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Orchestrate Agents',
      'description': 'Connect multiple AI agents together. Define workflows, routing rules, and seamless data handoffs.',
      'icon': Icons.hub_rounded,
      'glowColor': AppColors.primary,
    },
    {
      'title': 'Human-in-the-Loop',
      'description': 'Review and approve critical agent actions before they execute. Stay in complete control.',
      'icon': Icons.gpp_good_rounded,
      'glowColor': AppColors.success,
    },
    {
      'title': 'Full Transparency',
      'description': 'Detailed logs and reasoning traces for every action. Audit your agents at any time.',
      'icon': Icons.manage_search_rounded,
      'glowColor': AppColors.warning,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to Login or Dashboard
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dynamic gradient background based on current page
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  (_pages[_currentPage]['glowColor'] as Color).withOpacity(0.15),
                  AppColors.background,
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top App bar section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          context.go('/login');
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        data: _pages[index],
                        isActive: index == _currentPage,
                      );
                    },
                  ),
                ),
                
                // Bottom Section (Indicators & Button)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicators
                      Row(
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 6,
                            width: _currentPage == index ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      
                      // Next / Get Started Button
                      GestureDetector(
                        onTap: _nextPage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _currentPage == _pages.length - 1 ? 140 : 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _currentPage == _pages.length - 1
                                ? const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon Container
          AnimatedScale(
            scale: isActive ? 1.0 : 0.8,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface2,
                  boxShadow: [
                    BoxShadow(
                      color: (data['glowColor'] as Color).withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: (data['glowColor'] as Color).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  data['icon'],
                  size: 80,
                  color: data['glowColor'],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 64),
          
          // Text Content
          AnimatedSlide(
            offset: isActive ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  Text(
                    data['title'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    data['description'],
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
