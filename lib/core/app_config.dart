import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central config class — all API endpoints loaded from .env
/// Usage:  AppConfig.agents   or   AppConfig.aiRelay
class AppConfig {
  AppConfig._(); // prevent instantiation

  // ─── Supabase Base ─────────────────────────────────────────────────────────
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get supabaseSecretKey =>
      dotenv.env['SUPABASE_SECRET_KEY'] ?? '';

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static String get login =>
      dotenv.env['API_LOGIN'] ?? '$supabaseUrl/auth/v1/token?grant_type=password';

  static String get signup =>
      dotenv.env['API_SIGNUP'] ?? '$supabaseUrl/auth/v1/signup';

  static String get logout =>
      dotenv.env['API_LOGOUT'] ?? '$supabaseUrl/auth/v1/logout';

  // ─── Home / Dashboard ──────────────────────────────────────────────────────
  static String get dashboardStats =>
      dotenv.env['API_DASHBOARD_STATS'] ?? '$supabaseUrl/rest/v1/rpc/get_dashboard_stats';

  // ─── Agent Registry ────────────────────────────────────────────────────────
  static String get agents =>
      dotenv.env['API_AGENTS'] ?? '$supabaseUrl/rest/v1/agents';

  static String get agentCreate =>
      dotenv.env['API_AGENT_CREATE'] ?? '$supabaseUrl/rest/v1/agents';

  static String get agentUpdate =>
      dotenv.env['API_AGENT_UPDATE'] ?? '$supabaseUrl/rest/v1/agents';

  static String get agentDelete =>
      dotenv.env['API_AGENT_DELETE'] ?? '$supabaseUrl/rest/v1/agents';

  // ─── Messages ──────────────────────────────────────────────────────────────
  static String get messages =>
      dotenv.env['API_MESSAGES'] ?? '$supabaseUrl/rest/v1/messages';

  static String get messageApprove =>
      dotenv.env['API_MESSAGE_APPROVE'] ?? '$supabaseUrl/rest/v1/messages';

  static String get messageReject =>
      dotenv.env['API_MESSAGE_REJECT'] ?? '$supabaseUrl/rest/v1/messages';

  // ─── Rules ─────────────────────────────────────────────────────────────────
  static String get rules =>
      dotenv.env['API_RULES'] ?? '$supabaseUrl/rest/v1/rules';

  static String get ruleCreate =>
      dotenv.env['API_RULE_CREATE'] ?? '$supabaseUrl/rest/v1/rules';

  static String get ruleUpdate =>
      dotenv.env['API_RULE_UPDATE'] ?? '$supabaseUrl/rest/v1/rules';

  static String get ruleDelete =>
      dotenv.env['API_RULE_DELETE'] ?? '$supabaseUrl/rest/v1/rules';

  // ─── Audit Logs ────────────────────────────────────────────────────────────
  static String get auditLogs =>
      dotenv.env['API_AUDIT_LOGS'] ?? '$supabaseUrl/rest/v1/audit_logs';

  // ─── Inspector ─────────────────────────────────────────────────────────────
  static String get inspector =>
      dotenv.env['API_INSPECTOR'] ?? '$supabaseUrl/rest/v1/messages?select=*,agents(name)';

  // ─── AI Agent Relay ────────────────────────────────────────────────────────
  /// The AI model endpoint that agent messages are forwarded to
  static String get aiRelayEndpoint =>
      dotenv.env['AI_RELAY_ENDPOINT'] ??
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent';

  static String get aiApiKey =>
      dotenv.env['AI_API_KEY'] ?? '';
}
