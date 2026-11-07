import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/localization/app_translations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../shell/worker_shell_view.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  final bool isModalView;

  const TutorialScreen({super.key, this.isModalView = false});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_TutorialSlide> _slides = const [
    _TutorialSlide(
      icon: Icons.location_on_outlined,
      iconColor: AppColors.accentBlue,
      titleCebuano: 'Sona sa Trabaho (Geofencing)',
      titleEnglish: 'Work Zone Geofencing',
      descCebuano:
          'Makahimo lamang ka og log sa attendance kon anaa ka pisikal sa sulod sa imong assigned nga sona sa Ormoc City. Gisusi sa GPS ang imong posisyon matag 1 ka minuto samtang aktibo ang shift.',
      descEnglish:
          'You can only log attendance while physically inside your assigned Ormoc City work area. GPS validates your position every 1 minute while shift is active.',
    ),
    _TutorialSlide(
      icon: Icons.camera_alt_outlined,
      iconColor: AppColors.accentGreen,
      titleCebuano: 'Hulagway nga may Tatak (Watermark)',
      titleEnglish: 'Watermarked Photo Proofs',
      descCebuano:
          'Ang matag hulagway sa nahumang buluhaton awtomatikong mabutangan og opisyal nga tatak sa petsa, oras, ug GPS coordinates direkta sa litrato sa dili pa ipadala sa supervisor.',
      descEnglish:
          'Every accomplishment photo automatically has the official date, time, and GPS coordinates permanently burned directly onto the image pixels before upload.',
    ),
    _TutorialSlide(
      icon: Icons.verified_user_outlined,
      iconColor: AppColors.accentGreen,
      titleCebuano: 'Kalidad sa Serbisyo (Standing)',
      titleEnglish: 'Workforce Standing & Compliance',
      descCebuano:
          'Hupti ang maayong rekord sa trabaho! Ang tukmang attendance ug pagtuman sa mga buluhaton magpabilin kanimo sa Good Standing.',
      descEnglish:
          'Maintain a good standing record! Consistent on-time attendance and approved accomplishment reports keep your account verified and active.',
    ),
  ];

  Future<void> _completeTutorial() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'bantaygawa_has_seen_tutorial', value: 'true');

    if (!mounted) return;
    if (widget.isModalView) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkerShellView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeTutorial,
            child: Text(
              lang == AppLanguage.cebuano ? 'Laktawi' : 'Skip',
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final title = lang == AppLanguage.cebuano ? slide.titleCebuano : slide.titleEnglish;
                    final desc = lang == AppLanguage.cebuano ? slide.descCebuano : slide.descEnglish;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: slide.iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 50, color: slide.iconColor),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == index ? AppColors.primaryNavy : AppColors.border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action Button
              AppButton(
                label: _currentPage == _slides.length - 1
                    ? (lang == AppLanguage.cebuano ? 'Magsugod Na' : 'Get Started')
                    : (lang == AppLanguage.cebuano ? 'Sunod' : 'Next'),
                onPressed: () {
                  if (_currentPage < _slides.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _completeTutorial();
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialSlide {
  final IconData icon;
  final Color iconColor;
  final String titleCebuano;
  final String titleEnglish;
  final String descCebuano;
  final String descEnglish;

  const _TutorialSlide({
    required this.icon,
    required this.iconColor,
    required this.titleCebuano,
    required this.titleEnglish,
    required this.descCebuano,
    required this.descEnglish,
  });
}
