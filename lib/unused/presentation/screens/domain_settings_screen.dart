import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/settings_provider.dart';

// Theme
import '../theme/app_theme.dart';

// Config
import '../../config/domain_config.dart';

/// Domain Settings Screen
/// Allows users to easily change Kemono and Coomer domains
class DomainSettingsScreen extends StatefulWidget {
  const DomainSettingsScreen({super.key});

  @override
  State<DomainSettingsScreen> createState() => _DomainSettingsScreenState();
}

class _DomainSettingsScreenState extends State<DomainSettingsScreen> {
  final _kemonoController = TextEditingController();
  final _coomerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    _kemonoController.text = settingsProvider.kemonoDomain;
    _coomerController.text = settingsProvider.coomerDomain;
  }

  @override
  void dispose() {
    _kemonoController.dispose();
    _coomerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Domain Settings',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.getOnBackgroundColor(context),
          ),
        ),
        backgroundColor: AppTheme.getSurfaceColor(context),
        foregroundColor: AppTheme.getOnSurfaceColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppTheme.getOnSurfaceColor(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.restore,
              color: AppTheme.getOnSurfaceColor(context),
            ),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.mdPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Customize API Domains',
                  style: AppTheme.heading1Style.copyWith(
                    color: AppTheme.getOnBackgroundColor(context),
                  ),
                ),
                const SizedBox(height: AppTheme.smSpacing),
                Text(
                  'Change the domains used for accessing Kemono and Coomer APIs. This can help if certain domains are blocked or slow in your region.',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.lgSpacing),

                // Kemono Domain Section
                _buildDomainSection(
                  'Kemono Domain',
                  _kemonoController,
                  settings.kemonoDomain,
                  settings.isKemonoDomainValid,
                  'kemono',
                  DomainConfig.getDomainSuggestions(),
                  (domain) => settings.setKemonoDomain(domain),
                ),

                const SizedBox(height: AppTheme.lgSpacing),

                // Coomer Domain Section
                _buildDomainSection(
                  'Coomer Domain',
                  _coomerController,
                  settings.coomerDomain,
                  settings.isCoomerDomainValid,
                  'coomer',
                  DomainConfig.getDomainSuggestions(),
                  (domain) => settings.setCoomerDomain(domain),
                ),

                const SizedBox(height: AppTheme.xlSpacing),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Saving...'),
                            ],
                          )
                        : const Text('Save Settings'),
                  ),
                ),

                const SizedBox(height: AppTheme.mdSpacing),

                // Status Section
                _buildStatusSection(settings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDomainSection(
    String title,
    TextEditingController controller,
    String currentValue,
    bool isValid,
    String apiType,
    List<String> suggestions,
    Future<void> Function(String) onSave,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(
              apiType == 'kemono' ? Icons.cloud : Icons.cloud_queue,
              color: apiType == 'kemono' ? Colors.blue : Colors.purple,
              size: 24,
            ),
            const SizedBox(width: AppTheme.smSpacing),
            Text(
              title,
              style: AppTheme.titleStyle.copyWith(
                color: AppTheme.getOnBackgroundColor(context),
                fontSize: 18,
              ),
            ),
            if (!isValid) ...[
              const SizedBox(width: AppTheme.smSpacing),
              Icon(Icons.warning, color: AppTheme.errorColor, size: 20),
            ],
          ],
        ),
        const SizedBox(height: AppTheme.smSpacing),

        // Domain Input
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $apiType domain (e.g., $currentValue)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
              borderSide: BorderSide(
                color: isValid ? AppTheme.cardColor : AppTheme.errorColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smRadius),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            prefixIcon: Icon(
              apiType == 'kemono' ? Icons.cloud : Icons.cloud_queue,
              color: AppTheme.secondaryTextColor,
            ),
            suffixIcon: isValid
                ? Icon(Icons.check_circle, color: AppTheme.successColor)
                : Icon(Icons.error_outline, color: AppTheme.errorColor),
          ),
          style: AppTheme.bodyStyle,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Domain is required';
            }
            final cleanedValue = DomainConfig.cleanDomain(value.trim());
            if (!DomainConfig.isValidDomain(cleanedValue)) {
              return 'Invalid domain format';
            }
            return null;
          },
        ),

        const SizedBox(height: AppTheme.smSpacing),

        // Suggestions
        Text(
          'Suggestions:',
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: AppTheme.xsSpacing),

        Wrap(
          spacing: AppTheme.xsSpacing,
          runSpacing: AppTheme.xsSpacing,
          children: suggestions.map((suggestion) {
            final isSelected = controller.text.trim() == suggestion;
            return ActionChip(
              label: suggestion,
              backgroundColor: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.cardColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.primaryTextColor,
                fontSize: 12,
              ),
              onPressed: () {
                controller.text = suggestion;
                controller.selection = TextSelection.fromPosition(
                  base: TextPosition(offset: 0),
                  affinity: TextAffinity.upstream,
                );
              },
            );
          }).toList(),
        ),

        const SizedBox(height: AppTheme.mdSpacing),
      ],
    );
  }

  Widget _buildStatusSection(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mdPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.mdRadius),
        border: Border.all(color: AppTheme.cardColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Status',
            style: AppTheme.titleStyle.copyWith(
              color: AppTheme.getOnBackgroundColor(context),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppTheme.mdSpacing),

          // Kemono Status
          Row(
            children: [
              Icon(
                settings.isKemonoDomainValid
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: settings.isKemonoDomainValid
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.smSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kemono',
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.getOnBackgroundColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      settings.isKemonoDomainValid
                          ? '✓ ${settings.kemonoDomain}'
                          : '✗ Invalid domain',
                      style: AppTheme.captionStyle.copyWith(
                        color: settings.isKemonoDomainValid
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.smSpacing),

          // Coomer Status
          Row(
            children: [
              Icon(
                settings.isCoomerDomainValid
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: settings.isCoomerDomainValid
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.smSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coomer',
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.getOnBackgroundColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      settings.isCoomerDomainValid
                          ? '✓ ${settings.coomerDomain}'
                          : '✗ Invalid domain',
                      style: AppTheme.captionStyle.copyWith(
                        color: settings.isCoomerDomainValid
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _kemonoController.text = DomainConfig.defaultKemonoDomain;
      _coomerController.text = DomainConfig.defaultCoomerDomain;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reset to default domains'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      await settingsProvider.setKemonoDomain(_kemonoController.text.trim());
      await settingsProvider.setCoomerDomain(_coomerController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Domain settings saved successfully'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
