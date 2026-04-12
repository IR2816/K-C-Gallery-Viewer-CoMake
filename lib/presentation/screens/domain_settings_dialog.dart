import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../../config/domain_config.dart';
import 'domain_change_notifier.dart';

/// Animated domain settings dialog.
///
/// Displays current Kemono / Coomer domains, lets the user edit them with
/// real-time validation feedback, and previews the change before applying it.
/// On confirmation, shows [DomainChangeNotifier] toast notification.
class DomainSettingsDialog extends StatefulWidget {
  const DomainSettingsDialog({super.key});

  @override
  State<DomainSettingsDialog> createState() => _DomainSettingsDialogState();
}

class _DomainSettingsDialogState extends State<DomainSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _kemonoCtrl;
  late TextEditingController _coomerCtrl;

  bool _kemonoValid = true;
  bool _coomerValid = true;
  bool _isSaving = false;

  late AnimationController _dialogController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const Color _kemonoColor = Color(0xFF2196F3);
  static const Color _coomerColor = Color(0xFFFF6B6B);

  late String _initialKemonoDomain;
  late String _initialCoomerDomain;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _initialKemonoDomain = settings.cleanKemonoDomain;
    _initialCoomerDomain = settings.cleanCoomerDomain;
    _kemonoCtrl = TextEditingController(text: _initialKemonoDomain);
    _coomerCtrl = TextEditingController(text: _initialCoomerDomain);

    _dialogController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.easeOut),
    );

    _dialogController.forward();

    _kemonoCtrl.addListener(_validateInputs);
    _coomerCtrl.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _kemonoCtrl.dispose();
    _coomerCtrl.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  void _validateInputs() {
    setState(() {
      _kemonoValid =
          _kemonoCtrl.text.isEmpty ||
          DomainConfig.isValidDomain(
            DomainConfig.cleanDomain(_kemonoCtrl.text),
          );
      _coomerValid =
          _coomerCtrl.text.isEmpty ||
          DomainConfig.isValidDomain(
            DomainConfig.cleanDomain(_coomerCtrl.text),
          );
    });
  }

  bool get _hasChanges {
    return _kemonoCtrl.text.trim() != _initialKemonoDomain ||
        _coomerCtrl.text.trim() != _initialCoomerDomain;
  }

  Future<void> _save() async {
    if (!_kemonoValid || !_coomerValid) return;

    final settings = context.read<SettingsProvider>();
    final oldKemono = settings.cleanKemonoDomain;
    final oldCoomer = settings.cleanCoomerDomain;
    final newKemono = DomainConfig.cleanDomain(_kemonoCtrl.text.trim());
    final newCoomer = DomainConfig.cleanDomain(_coomerCtrl.text.trim());

    setState(() => _isSaving = true);

    try {
      if (newKemono.isNotEmpty && newKemono != oldKemono) {
        await settings.setKemonoDomain(newKemono);
      }
      if (newCoomer.isNotEmpty && newCoomer != oldCoomer) {
        await settings.setCoomerDomain(newCoomer);
      }

      // Eagerly clear the image cache so stale thumbnails are evicted
      // immediately, regardless of which screen is currently mounted.
      if ((newKemono.isNotEmpty && newKemono != oldKemono) ||
          (newCoomer.isNotEmpty && newCoomer != oldCoomer)) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      // Show notification for each changed domain
      if (newKemono.isNotEmpty && newKemono != oldKemono) {
        DomainChangeNotifier.show(
          context,
          oldDomain: oldKemono,
          newDomain: newKemono,
          apiSource: 'kemono',
        );
      }
      if (newCoomer.isNotEmpty && newCoomer != oldCoomer) {
        DomainChangeNotifier.show(
          context,
          oldDomain: oldCoomer,
          newDomain: newCoomer,
          apiSource: 'coomer',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update domain: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Domain Configuration',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Enter domain without https://',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Kemono domain field
                  _buildDomainField(
                    label: 'Kemono Domain',
                    controller: _kemonoCtrl,
                    color: _kemonoColor,
                    icon: Icons.circle,
                    isValid: _kemonoValid,
                    hint: 'e.g. kemono.cr',
                  ),

                  const SizedBox(height: 16),

                  // Coomer domain field
                  _buildDomainField(
                    label: 'Coomer Domain',
                    controller: _coomerCtrl,
                    color: _coomerColor,
                    icon: Icons.circle,
                    isValid: _coomerValid,
                    hint: 'e.g. coomer.st',
                  ),

                  const SizedBox(height: 16),

                  // Suggestions
                  _buildSuggestions(),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        opacity:
                            (_hasChanges &&
                                _kemonoValid &&
                                _coomerValid &&
                                !_isSaving)
                            ? 1.0
                            : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton.icon(
                          onPressed:
                              (_hasChanges &&
                                  _kemonoValid &&
                                  _coomerValid &&
                                  !_isSaving)
                              ? _save
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDomainField({
    required String label,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
    required bool isValid,
    required String hint,
  }) {
    final initialValue = label.toLowerCase().contains('kemono')
        ? _initialKemonoDomain
        : _initialCoomerDomain;
    final isChanged =
        controller.text.trim() != initialValue &&
        controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const Spacer(),
            if (isChanged)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CHANGED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: color.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isValid
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('valid'),
                            color: Colors.green,
                            size: 18,
                          )
                        : const Icon(
                            Icons.cancel_rounded,
                            key: ValueKey('invalid'),
                            color: Colors.red,
                            size: 18,
                          ),
                  )
                : null,
            errorText: !isValid ? 'Invalid domain format' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    final suggestions = DomainConfig.getDomainSuggestions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KNOWN DOMAINS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((d) {
            final isKemono = d.contains('kemono');
            final color = isKemono ? _kemonoColor : _coomerColor;
            return GestureDetector(
              onTap: () {
                if (isKemono) {
                  _kemonoCtrl.text = d;
                } else {
                  _coomerCtrl.text = d;
                }
                _validateInputs();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Shows [DomainSettingsDialog] as a modal and returns true if changes were
/// saved.
Future<bool?> showDomainSettingsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const DomainSettingsDialog(),
  );
}
