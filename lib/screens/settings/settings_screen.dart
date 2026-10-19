import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _displayName = 'Agent Owner';
  String _email = '';
  String _phone = '+1 (555) 019-2834';
  String _role = 'Owner';

  String _selectedProvider = 'Groq AI (Fast)';
  double _temperature = 0.3;
  bool _streamResponses = true;
  final TextEditingController _apiKeyController = TextEditingController();

  bool _interAgentBridgeEnabled = true;
  bool _requireOwnerApproval = true;
  bool _autoRejectViolations = true;
  final double _spendingLimit = 150.0;

  bool _notifyAgentMessages = true;
  bool _notifyDeliveryMilestones = true;
  bool _notifySecurityAlerts = true;

  bool _hapticFeedback = true;
  bool _compactView = false;
  String _themeMode = 'Dark (Default)';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _email = user.email ?? 'owner@agentbridge.ai';
      try {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          _displayName = profile['name'] ?? profile['full_name'] ?? 'Agent Owner';
          _phone = profile['phone'] ?? _phone;
          _role = profile['role'] ?? 'Owner';
        } else {
          _displayName = user.userMetadata?['name'] ?? 'Agent Owner';
        }
      } catch (e) {
        debugPrint('[Settings] Error fetching profile: $e');
        _displayName = user.userMetadata?['name'] ?? 'Agent Owner';
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Display Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Enter your name'),
              ),
              const SizedBox(height: 16),
              const Text('Contact Phone', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Enter phone number'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    final newPhone = phoneController.text.trim();
                    final uid = _supabase.auth.currentUser?.id;

                    if (uid != null && newName.isNotEmpty) {
                      try {
                        await _supabase.from('profiles').upsert({
                          'id': uid,
                          'name': newName,
                          'phone': newPhone,
                          'updated_at': DateTime.now().toIso8601String(),
                        });
                      } catch (e) {
                        debugPrint('[Settings] Profile update error: $e');
                      }
                    }

                    setState(() {
                      _displayName = newName.isNotEmpty ? newName : _displayName;
                      _phone = newPhone.isNotEmpty ? newPhone : _phone;
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnackbar('Profile updated successfully');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('API Keys Management', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Override default environment API keys for testing models directly:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Enter Groq or Gemini Key'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showSnackbar('API key preference saved');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to sign out from AgentBridge?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.auth.signOut();
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Local Cache', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will purge locally cached FakeStore API products, prompt buffers, and offline drafts. Continue?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackbar('Cache cleared successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Purge Cache', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings & Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              children: [
                _buildUserProfileCard(),
                const SizedBox(height: 24),

                _buildSectionHeader('AI & MODEL CORE', Icons.psychology_rounded, AppColors.primary),
                const SizedBox(height: 10),
                _buildModelSettings(),
                const SizedBox(height: 24),

                _buildSectionHeader('SECURITY & GUARDRAILS', Icons.security_rounded, AppColors.warning),
                const SizedBox(height: 10),
                _buildSecuritySettings(),
                const SizedBox(height: 24),

                _buildSectionHeader('NOTIFICATIONS & ALERTS', Icons.notifications_active_rounded, AppColors.success),
                const SizedBox(height: 10),
                _buildNotificationSettings(),
                const SizedBox(height: 24),

                _buildSectionHeader('APP PREFERENCES', Icons.tune_rounded, AppColors.textSecondary),
                const SizedBox(height: 10),
                _buildPreferenceSettings(),
                const SizedBox(height: 24),

                _buildSectionHeader('DATA & ACCOUNT', Icons.admin_panel_settings_rounded, AppColors.error),
                const SizedBox(height: 10),
                _buildDangerZone(),
              ],
            ),
    );
  }

  Widget _buildUserProfileCard() {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'O';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _role.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _phone,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Full Workspace Access',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                label: const Text('Edit', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildModelSettings() {
    return _buildContainerCard([
      _buildDropdownTile(
        title: 'Primary AI Provider',
        subtitle: 'Used for shopping and routing decisions',
        value: _selectedProvider,
        options: const [
          'Groq AI (Fast)',
          'Google Gemini 3.8 Flash',
          'OpenAI GPT-4o Mini',
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedProvider = val);
        },
      ),
      const Divider(color: AppColors.border, height: 1),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Model Temperature', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Factual (0.0) to Creative (1.0)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _temperature.toStringAsFixed(1),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surface2,
              onChanged: (val) => setState(() => _temperature = val),
            ),
          ],
        ),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Stream Token Responses',
        subtitle: 'Display agent reasoning word-by-word',
        value: _streamResponses,
        onChanged: (val) => setState(() => _streamResponses = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      ListTile(
        title: const Text('Custom API Keys & Relay', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: const Text('Manage custom keys or self-hosted relays', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
        onTap: _showApiKeyDialog,
      ),
    ]);
  }

  Widget _buildSecuritySettings() {
    return _buildContainerCard([
      _buildSwitchTile(
        title: 'Inter-Agent Communication Bridge',
        subtitle: 'Allow Shopping Agent to dispatch orders to Delivery Agent',
        value: _interAgentBridgeEnabled,
        onChanged: (val) => setState(() => _interAgentBridgeEnabled = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Require Owner Dispatch Approval',
        subtitle: 'Hold dispatch orders in pending status until human approves',
        value: _requireOwnerApproval,
        onChanged: (val) => setState(() => _requireOwnerApproval = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Auto-Block Guardrail Keywords',
        subtitle: 'Reject messages containing sensitive topics immediately',
        value: _autoRejectViolations,
        onChanged: (val) => setState(() => _autoRejectViolations = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max Auto-Approval Spending', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Orders above this amount require confirmation', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '\$${_spendingLimit.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildNotificationSettings() {
    return _buildContainerCard([
      _buildSwitchTile(
        title: 'Inter-Agent Message Inquiries',
        subtitle: 'Alerts when Delivery Agent asks Shopping Agent questions',
        value: _notifyAgentMessages,
        onChanged: (val) => setState(() => _notifyAgentMessages = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Order Tracking & Delivery ETAs',
        subtitle: 'Milestone notifications on FedEx dispatch & delivery',
        value: _notifyDeliveryMilestones,
        onChanged: (val) => setState(() => _notifyDeliveryMilestones = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Security & Permission Alerts',
        subtitle: 'Instant alerts on blocked keywords or rate-limit hits',
        value: _notifySecurityAlerts,
        onChanged: (val) => setState(() => _notifySecurityAlerts = val),
      ),
    ]);
  }

  Widget _buildPreferenceSettings() {
    return _buildContainerCard([
      _buildDropdownTile(
        title: 'App Theme',
        subtitle: 'Color aesthetic for AgentBridge',
        value: _themeMode,
        options: const ['Dark (Default)', 'Light', 'System'],
        onChanged: (val) {
          if (val != null) setState(() => _themeMode = val);
        },
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Haptic Feedback',
        subtitle: 'Vibrate on rule approvals and dispatch triggers',
        value: _hapticFeedback,
        onChanged: (val) => setState(() => _hapticFeedback = val),
      ),
      const Divider(color: AppColors.border, height: 1),
      _buildSwitchTile(
        title: 'Compact Inspection Cards',
        subtitle: 'Condense JSON payload views on inspector and messages',
        value: _compactView,
        onChanged: (val) => setState(() => _compactView = val),
      ),
    ]);
  }

  Widget _buildDangerZone() {
    return _buildContainerCard([
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 20),
        ),
        title: const Text('Clear Product Catalog Cache', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: const Text('Re-fetch fresh inventory from FakeStore API', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        onTap: _confirmClearCache,
      ),
      const Divider(color: AppColors.border, height: 1),
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.download_rounded, color: AppColors.success, size: 20),
        ),
        title: const Text('Export Audit Records', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: const Text('Export inter-agent transactions as JSON', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        onTap: () => _showSnackbar('Audit log bundle exported to clipboard'),
      ),
      const Divider(color: AppColors.border, height: 1),
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
        ),
        title: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
        subtitle: const Text('End current session on this device', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        onTap: _confirmSignOut,
      ),
    ]);
  }

  Widget _buildContainerCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      value: value,
      activeTrackColor: AppColors.primary,
      activeThumbColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                items: options.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt));
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
