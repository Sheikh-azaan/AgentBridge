import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  int _totalAgents = 0;
  int _pendingMessages = 0;
  int _approvedMessages = 0;
  int _rejectedMessages = 0;
  bool _loading = true;
  String _userName = '';

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    String userName = 'Owner';
    int agentsCount = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    try {
      final profile = await _supabase.from('profiles').select('name').eq('id', uid).maybeSingle();
      userName = profile?['name'] ?? 'Owner';
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    try {
      final agents = await _supabase.from('agents').select('id').eq('owner_id', uid).eq('is_active', true);
      agentsCount = (agents as List).length;
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }

    try {
      final messages = await _supabase.from('messages').select('status').eq('owner_id', uid);
      final msgs = messages as List;
      pending = msgs.where((m) => m['status'] == 'pending').length;
      approved = msgs.where((m) => m['status'] == 'approved').length;
      rejected = msgs.where((m) => m['status'] == 'rejected').length;
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }

    if (mounted) {
      setState(() {
        _userName = userName;
        _totalAgents = agentsCount;
        _pendingMessages = pending;
        _approvedMessages = approved;
        _rejectedMessages = rejected;
        _loading = false;
      });
      _animController.forward();
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'delivery',
            onPressed: () => context.push('/delivery'),
            backgroundColor: Colors.green,
            icon: const Icon(Icons.local_shipping, color: Colors.white),
            label: const Text('Delivery Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'shopping',
            onPressed: () => context.push('/demo'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
            label: const Text('Shopping Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : FadeTransition(
                opacity: _fadeIn,
                child: RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: CustomScrollView(
                    slivers: [
                      // ─── Header ───
                      SliverToBoxAdapter(child: _buildHeader()),

                      // ─── Stats Grid ───
                      SliverToBoxAdapter(child: _buildStatsGrid()),

                      // ─── Quick Actions ───
                      SliverToBoxAdapter(child: _buildQuickActions()),

                      // ─── Live Agent Hub (Multi-Agent Demos) ───
                      SliverToBoxAdapter(child: _buildAgentDemos()),

                      // ─── Recent Activity placeholder ───
                      SliverToBoxAdapter(child: _buildRecentActivity()),

                      const SliverToBoxAdapter(child: SizedBox(height: 100)), // Extra space for FAB
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Notification + Logout
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stats Grid
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                label: 'Active Agents',
                value: '$_totalAgents',
                icon: Icons.hub_rounded,
                color: AppColors.primary,
              ),
              _StatCard(
                label: 'Pending',
                value: '$_pendingMessages',
                icon: Icons.hourglass_top_rounded,
                color: AppColors.warning,
              ),
              _StatCard(
                label: 'Approved',
                value: '$_approvedMessages',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              _StatCard(
                label: 'Rejected',
                value: '$_rejectedMessages',
                icon: Icons.cancel_rounded,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Quick Actions
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Agents',
                  icon: Icons.smart_toy_rounded,
                  color: AppColors.primary,
                  onTap: () => context.push('/agents'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Messages',
                  icon: Icons.message_rounded,
                  color: AppColors.warning,
                  onTap: () => context.push('/messages'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Rules',
                  icon: Icons.rule_rounded,
                  color: AppColors.success,
                  onTap: () => context.push('/rules'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Audit',
                  icon: Icons.history_rounded,
                  color: AppColors.textSecondary,
                  onTap: () => context.push('/audit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Live Agent Hub (Multi-Agent)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAgentDemos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Live Agent Hub',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Multi-Agent Bridge',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Delivery Agent Card
          GestureDetector(
            onTap: () => context.push('/delivery'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Agent (Gemini + Supabase)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Trained on live Supabase orders table via Gemini API',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Shopping Agent Card
          GestureDetector(
            onTap: () => context.push('/demo'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shopping Agent (Groq AI)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Product search, recommendations & agent handoff',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Recent Activity
  // ─────────────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/audit'),
                child: const Text(
                  'See all',
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_pendingMessages == 0 && _approvedMessages == 0 && _rejectedMessages == 0)
            _buildEmptyActivity()
          else
            _buildActivityList(),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No activity yet',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Register your first agent to get started',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (_pendingMessages > 0)
            _ActivityTile(
              icon: Icons.hourglass_top_rounded,
              color: AppColors.warning,
              title: '$_pendingMessages message(s) awaiting approval',
              subtitle: 'Tap Messages to review',
            ),
          if (_approvedMessages > 0)
            _ActivityTile(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              title: '$_approvedMessages message(s) approved',
              subtitle: 'Forwarded to destination agents',
            ),
          if (_rejectedMessages > 0)
            _ActivityTile(
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              title: '$_rejectedMessages message(s) rejected',
              subtitle: 'Blocked by owner decision',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }
}
