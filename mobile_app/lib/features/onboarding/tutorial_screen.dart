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
      titleFilipino: 'Sona ng Trabaho (Geofencing)',
      titleEnglish: 'Work Zone Geofencing',
      descFilipino:
          'Maaari ka lamang mag-log ng attendance kung ikaw ay pisikal na nasa loob ng iyong itinalagang sona sa Ormoc City. Sinusuri ng GPS ang iyong lokasyon bawat 1 minuto.',
      descEnglish:
          'You can only log attendance while physically inside your assigned Ormoc City work area. GPS validates your position every 1 minute while shift is active.',
    ),
    _TutorialSlide(
      icon: Icons.camera_alt_outlined,
      iconColor: AppColors.accentGreen,
      titleFilipino: 'Litrato na may Tatak (Watermark)',
      titleEnglish: 'Watermarked Photo Proofs',
      descFilipino:
          'Bawat patunay ng trabaho ay awtomatikong lalagyan ng opisyal na tatak ng petsa, oras, at GPS coordinates nang direkta sa litrato bago ipadala sa supervisor.',
      descEnglish:
          'Every accomplishment photo automatically has the official date, time, and GPS coordinates permanently burned directly onto the image pixels before upload.',
    ),
    _TutorialSlide(
      icon: Icons.workspace_premium_outlined,
      iconColor: AppColors.warningOrange,
      titleFilipino: 'Kredito sa Pagganap (Credit Score)',
      titleEnglish: 'Performance Credit Score',
      descFilipino:
          'Panatilihing berde (80-100) ang iyong marka! Ang regular na attendance at naaprubahang ulat ay nagdaragdag ng puntos, habang ang pagliban ay may bawas.',
      descEnglish:
          'Keep your score in the green tier (80-100)! On-time attendance and approved reports add points, while unexcused absences deduct points.',
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
              lang == AppLanguage.filipino ? 'Laktawan' : 'Skip',
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
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: slide.iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(slide.icon, size: 60, color: slide.iconColor),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          lang == AppLanguage.filipino ? slide.titleFilipino : slide.titleEnglish,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          lang == AppLanguage.filipino ? slide.descFilipino : slide.descEnglish,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
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
                    ? (lang == AppLanguage.filipino ? 'Magsimula Na' : 'Get Started')
                    : (lang == AppLanguage.filipino ? 'Susunod' : 'Next'),
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
  final String titleFilipino;
  final String titleEnglish;
  final String descFilipino;
  final String descEnglish;

  const _TutorialSlide({
    required this.icon,
    required this.iconColor,
    required this.titleFilipino,
    required this.titleEnglish,
    required this.descFilipino,
    required this.descEnglish,
  });
}
