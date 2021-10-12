# -*- coding: utf-8 -*-
# vim: ft=sls

# Get status for idx, sh, cm, lm, or ds using cli command
{% macro check_splunk_status(node, node_type) %}
# If service not running this will fail
orch-function-check-splunk-status-{{ node_type }}:
  salt.function:
    - name: cmd.run
    - tgt: {{ node }}
    - arg:
      - {{ config.splunk.base_dir }}/bin/splunk status |grep "is running" && exit 0
    - kwarg:
        runas: splunk
    - onfail_in:
      - test: orch-test-status-checks-failed-aborting-updates
{% endmacro %}

# Get maintenance mode status
{% macro check_maint_mode_status() %}
# False is the value we expect so this fails when true
orch-command-check-maint-mode-splunk-cm:
  cmd.run:
    - name: curl -k -sS -u $rest_user:"$rest_user_pass" https://$splunk_api_url/$splunk_api_path | $splunk_api_filter |grep false && exit 0
    - env:
        - rest_user: {{ config.splunk.admin_user }}
        - rest_user_pass: {{ config.splunk.current_admin_pass }}
        - splunk_api_url: {{ config.splunk.splunk_cm_uri }}:{{ config.splunk.splunk_mgmt_port }}
        - splunk_api_path: 'services/cluster/master/status?output_mode=json'
        - splunk_api_filter: 'jq .entry[].content.maintenance_mode'
    - hide_output: True
    - output_loglevel: quiet
    - onfail_in:
      - test: orch-test-status-checks-failed-aborting-updates
{% endmacro %}

