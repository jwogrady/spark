"""The runtime modules' responsibilities, in the same eight buckets as the dispatcher's (#743).

Module functions are named by domain prefix — `tm_` telemetry, `bg_` budget, `ev_` evidence, `route_`/`rt_` routing
policy, `ci_` continuous integration, `xr_` crossroad, `plan_` planning, `repo_` repository binding — and each is
assigned by what its body owns, on the same rule as the dispatcher's map: a body that reads and renders is filed
under the half it owns. Names removed by this work unit are kept here so the before-change map can be generated
from the same classification.
"""
MODULE_RESP = {
"argument-parsing": [],
"routing-dispatch": ["route_policy_file", "route_rows", "route_class_rank", "route_model", "route_effort"],
"source-collection": [
    "facts_rules_read",
    "tm_dir", "tm_file", "tm_exec_count", "tm_footprint_bytes", "tm_footprint_modules", "tm_get", "tm_load",
    "tm_live_head", "bg_file", "bg_load", "ev_dir", "ev_file", "ev_payload", "ev_get", "ev_load",
    "rt_dir", "rt_run", "rt_ledger", "rt_get", "ci_file", "ci_load", "ci_live", "ci_failing_set",
    "plan_script", "plan_schema_rows", "plan_ref_num", "plan_ms_title", "plan_sub_issues", "plan_relation_rows",
    "plan_live_rows", "plan_created_rows", "repo_binding_path", "repo_bound_locator", "repo_fact",
    "repo_target_of_command", "repo_gh_repo_of_command",
    "facts_now", "facts_repo_node", "facts_load_grammars",
    "facts_unit_node", "facts_unit_read"],
"canonicalization": [
    "tm_is_key", "tm_is_int_key", "tm_valid_run", "tm_cache_ratio", "tm_delta", "bg_is_key", "bg_is_int_key",
    "bg_stage", "ev_tokens", "plan_label_scope", "artifact_labels", "label_set_equal", "plan_body_matches",
    "repo_locator_normalize", "repo_identity", "facts_unreadable_reason", "facts_canonical", "facts_state_canonical", "facts_check_state", "facts_check_worse", "facts_graph_entry",
    "facts_unit_kind", "facts_unit_locator", "facts_error_absent"],
"domain-semantics": [
    "tm_hot_cycle", "cmd_telemetry", "bg_apply_staged", "bg_ambiguous", "bg_write", "bg_over", "bg_over_cost",
    "cmd_budget", "ev_write", "ev_drift", "cmd_evidence", "cmd_route", "ci_write", "ci_observe", "cmd_ci",
    "xr_stop_check", "cmd_crossroad", "plan_resolve_labels", "plan_has_label_updates", "cmd_plan",
    "repo_bind", "repo_authorize", "cmd_repo", "cmd_facts"],
"evidence-authority": [
    "tm_no_progress", "tm_binding_status", "bg_reject_framing", "ci_sentinel_state", "ci_verdict",
    "tm_secret_shaped", "facts_repository_fact", "facts_graph_fact", "facts_work_unit_fact",
    "facts_placement_fact", "facts_acceptance_fact", "facts_head_fact", "facts_review_fact", "facts_checks_fact"],
"formatting-reporting": [
    "facts_envelope_tail", "facts_record_telemetry","label_set_show", "ci_sentinel_report", "json_escape_out", "bg_json_escape",
    # nested helpers: row printers inside the verb that prints them
    "tm_row", "bg_row"],
"compatibility-fallback": [],
}
