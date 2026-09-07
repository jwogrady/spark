"""The dispatcher's responsibilities, one bucket per function — #743's "map before you change" requirement.

The eight names are the issue's own vocabulary. Assignment is by what the body *owns*: a function that reads a
source and also renders it is assigned to the heavier half, and the manifest says so rather than pretending the
buckets are disjoint in this code.
"""
RESP = {
"argument-parsing": ["usage"],
"routing-dispatch": ["spark_module_for", "spark_load_module", "spark_load_all_modules",
    "spark_runtime_source_bytes", "spark_record_runtime_footprint"],
"source-collection": ["__spark_memo_key", "__spark_memo_read", "git_root", "check_json", "prefs_operator_path",
    "read_flat_json", "pref_get", "repo_git_facts", "repo_open_pr", "repo_recorded_intent", "repo_classification",
    "repo_trunk", "repo_manifest_names", "tracked_content_count", "governance_shipped_model",
    "governance_operator_model", "governance_project_model", "governance_records", "di_trunk", "di_repo_nwo",
    "gh_blocked_by", "di_release_labels", "di_release_branch_prefix", "di_linked_prs", "di_pr_paths",
    "gov_live_labels", "gov_label_rows", "gov_issue_rows", "gov_gate_capture", "gov_file_rows", "gov_collect",
    "triage_rows", "milestone_snapshot", "course_evidence", "fp_bytes_lines", "fp_files", "fp_desc_chars",
    "fp_plugin_bytes", "ruleset_required_checks", "now_ms", "fp_run_ms", "fp_median3_ms", "fp_hot_guard",
    "fp_hot_brief", "fp_hot_doctor", "fp_hot_governance", "ro_snapshot", "ro_isolate", "ro_release",
    "next_impl_prs", "intent_liveness"],
"canonicalization": ["merge_strategy_known", "permission_baseline", "resolve_prefs", "issue_refs",
    "classification_drifted", "resolve_governance", "governance_family_members", "governance_member_from",
    "governance_structure_fact", "release_gate_label", "resolve_issue_taxonomy", "taxonomy_label_color",
    "taxonomy_label_desc", "di_classify", "di_split_linked", "rec_row", "rec_protected_branch", "ms_inventory_of",
    "containers_of", "suborder_of", "governance_family_required", "milestone_inventory", "priority_members",
    "active_in_inventory", "completed_in_inventory", "leaves_in_inventory", "current_milestone",
    "completed_milestones", "hub_locator_valid"],
"domain-semantics": ["lint_skill_md", "doctor_requirements", "apply_standard", "classify_repo",
    "di_exclusive_violated", "rec_rows", "rec_apply_one", "rec_apply", "orient_set", "hub_set",
    "fp_footprint_gate", "fp_cache_stability", "check_tier_boundary", "check_reference_laziness",
    "check_release_component_parity", "fp_latency", "next_select", "next_route", "cmd_version", "cmd_doctor",
    "cmd_new_skill", "cmd_preferences", "cmd_list_skills", "cmd_brief", "cmd_labels", "cmd_docs_impact",
    "cmd_reconcile", "cmd_course", "cmd_triage", "cmd_governance", "cmd_orient", "cmd_hub",
    "cmd_install_git_hooks", "cmd_profiles", "cmd_setup", "cmd_apply_permissions", "cmd_resume", "cmd_footprint",
    "cmd_state", "cmd_next"],
"evidence-authority": ["governance_validate", "di_grade", "di_evidence_failed", "release_gate_projection",
    "gov_cycle_rows", "gov_judgment_rows", "gov_mechanical_rows", "gov_admissible", "rec_kind",
    "rec_still_present", "snapshot_unread", "remote_enforcement_verdict", "ro_probe"],
"formatting-reporting": ["red", "green", "yellow", "gov_cmd_render", "di_report", "release_gate_render",
    "gov_gate_rows", "gov_render", "prio_show", "next_report_impl_prs", "json_escape"],
"compatibility-fallback": ["is_legacy_key", "gov_fallback_desc"],
}
