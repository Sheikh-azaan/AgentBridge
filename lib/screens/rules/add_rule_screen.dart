import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../models/agent.dart';

class AddRuleScreen extends StatefulWidget {
  const AddRuleScreen({super.key});

  @override
  State<AddRuleScreen> createState() => _AddRuleScreenState();
}

class _AddRuleScreenState extends State<AddRuleScreen> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedType = 'system_prompt';
  String? _selectedAgentId;
  List<Agent> _agents = [];
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final response = await _supabase.from('agents').select().eq('owner_id', uid);
      final List data = response as List;
      setState(() {
        _agents = data.map((e) => Agent.fromMap(e)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching agents: $e');
    }
  }

  Future<void> _saveRule() async {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (name.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Rule Name and Content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _supabase.auth.currentUser?.id;
      await _supabase.from('rules').insert({
        'owner_id': uid,
        'agent_id': _selectedAgentId,
        'rule_name': name,
        'rule_type': _selectedType,
        'content': content,
        'is_active': true,
      });

      // Audit log
      await _supabase.from('audit_logs').insert({
        'owner_id': uid,
        'action': 'rule_created',
        'description': 'Created agent rule: $name ($_selectedType)',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Agent Rule',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.rule_rounded, size: 48, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),

            // Rule Name
            _buildLabel('Rule Name *'),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'e.g. Reject Financial Advice', Icons.title_rounded),
            const SizedBox(height: 20),

            // Rule Type Dropdown
            _buildLabel('Rule Type'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'system_prompt',
                      child: Text('System Prompt (Direct agent behavior)', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'guardrail',
                      child: Text('Guardrail (Block unsafe responses)', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'action_policy',
                      child: Text('Action Policy (Restrict allowed APIs)', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Target Agent Dropdown
            _buildLabel('Assign To Agent'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedAgentId,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  hint: const Text('All Active Agents (Global Rule)', style: TextStyle(color: AppColors.textMuted)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Active Agents (Global Rule)', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    ..._agents.map(
                      (agent) => DropdownMenuItem<String?>(
                        value: agent.id,
                        child: Text(agent.name, style: const TextStyle(color: AppColors.textPrimary)),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedAgentId = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rule Content
            _buildLabel('Rule Instructions / Prompt Content *'),
            const SizedBox(height: 8),
            _buildTextField(
              _contentController,
              'Write the exact rule or system prompt instructions for the AI agent...',
              Icons.article_outlined,
              maxLines: 5,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save & Apply Rule',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
