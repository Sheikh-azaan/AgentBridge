import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AgentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> agent;

  const AgentDetailScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final bool isActive = agent['is_active'] ?? false;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Agent Details',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: isActive ? AppColors.success.withOpacity(0.15) : AppColors.textMuted.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy_rounded, 
                  size: 52, 
                  color: isActive ? AppColors.success : AppColors.textMuted
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Text(
                agent['name'] ?? 'Unnamed Agent',
                style: const TextStyle(
                  color: AppColors.textPrimary, 
                  fontSize: 24, 
                  fontWeight: FontWeight.w800
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success.withOpacity(0.12) : AppColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: isActive ? AppColors.success : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            
            const Text(
              'Information',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildDetailCard(
              icon: Icons.description_outlined,
              title: 'Description',
              value: agent['description']?.toString().isNotEmpty == true 
                  ? agent['description'] 
                  : 'No description provided.',
            ),
            const SizedBox(height: 12),
            
            _buildDetailCard(
              icon: Icons.link_rounded,
              title: 'API Endpoint',
              value: agent['api_endpoint']?.toString().isNotEmpty == true 
                  ? agent['api_endpoint'] 
                  : 'No endpoint set.',
            ),
            const SizedBox(height: 12),
            
            _buildDetailCard(
              icon: Icons.calendar_today_rounded,
              title: 'Created At',
              value: agent['created_at'] != null 
                  ? DateTime.tryParse(agent['created_at'])?.toLocal().toString().split('.')[0] ?? agent['created_at']
                  : 'Unknown',
            ),
            const SizedBox(height: 12),
            
            _buildDetailCard(
              icon: Icons.vpn_key_outlined,
              title: 'Agent ID',
              value: agent['id'] ?? 'Unknown',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailCard({required IconData icon, required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
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
