# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Include patch and reboot macro
{% from slspath + "/macro-patch-and-reboot.sls" import patch_and_reboot with context %}

# Include status check macros
{% from slspath + "/macro-check-splunk-status.sls" import check_splunk_status, check_maint_mode_status with context %}

# Set license server target values
{% set lm_target = 'splunk-license*' %}
{{ check_splunk_status(lm_target, 'lm') }}

# Set deployment server target values
{% set ds_target = 'splunk-deployment*' %}
{{ check_splunk_status(ds_target, 'ds') }}

# Set cluster master target values
{% set cm_target = 'splunk-cluster*' %}
{{ check_splunk_status(cm_target, 'cm') }}
{{ check_maint_mode_status() }}

# Set search head target values
{% set sh_target = 'splunk-search*' %}
{{ check_splunk_status(sh_target, 'sh') }}

# Set indexer target values
{% set idx_target = 'splunk-indexer*' %}
{{ check_splunk_status(idx_target, 'idx') }}

# Run checks and if any fail, abort the process
# If all hosts are not up, we should find out why
orch-test-status-checks-failed-aborting-updates:
  test.fail_without_changes:
    - failhard: True

# Patch and reboot license masters
{% set lm_nodes = salt.saltutil.runner('cache.grains', tgt=lm_target, tgt_type='compound') %}
{% for lm in lm_nodes.keys() %}
  {{ patch_and_reboot(lm) }}
{% endfor %}

# Patch and reboot deployment servers
{% set ds_nodes = salt.saltutil.runner('cache.grains', tgt=ds_target, tgt_type='compound') %}
{% for ds in ds_nodes.keys() %}
  {{ patch_and_reboot(ds) }}
{% endfor %}

# Patch and reboot cluster master
{% set cm_nodes = salt.saltutil.runner('cache.grains', tgt=cm_target, tgt_type='compound') %}
{% for cm in cm_nodes.keys() %}
  {{ patch_and_reboot(cm) }}
{% endfor %}

# Patch and reboot search heads
{% set sh_nodes = salt.saltutil.runner('cache.grains', tgt=sh_target, tgt_type='compound') %}
{% for sh in sh_nodes.keys() %}
  {{ patch_and_reboot(sh) }}
{% endfor %}

# Patch and reboot indexers

# Set status to true if maintenance mode is false
orch-command-enable-maintenance-mode-splunk-cm:
  cmd.run:
    - name: curl -k -sS -X POST -u $rest_user:"$rest_user_pass" -d mode=true https://$splunk_api_url/$splunk_api_path | $splunk_api_filter
    - env:
      - rest_user: {{ config.splunk.admin_user }}
      - rest_user_pass: {{ config.splunk.current_admin_pass }}
      - splunk_api_url: {{ config.splunk.splunk_cm_uri }}:{{ config.splunk.splunk_mgmt_port }}
      - splunk_api_path: 'services/cluster/master/control/default/maintenance?output_mode=json'
      - splunk_api_filter: 'jq .'
    - output_loglevel: quiet
    - onchanges:
      - cmd: orch-command-check-maint-mode-splunk-cm

# Set search target values
{% set idx_nodes = salt.saltutil.runner('cache.grains', tgt=idx_target, tgt_type='compound') %}
{% for idx in idx_nodes.keys() %}

# Take Splunk offline to reassign primaries prior to patching
orch-function-offline-{{ idx }}:
  salt.function:
    - name: cmd.run
    - tgt: {{ idx }}
    - arg:
      - {{ config.splunk.base_dir }}/bin/splunk offline -auth $splunk_user:"$splunk_pass"
    - kwarg:
        env:
          - splunk_user: {{ config.splunk.admin_user }}
          - splunk_pass: {{ config.splunk.current_admin_pass }}
        output_loglevel: quiet
        runas: splunk
    - onchanges_in:
      - cmd: orch-command-disable-maintenance-mode-splunk-cm

  # Call macro to patch and reboot splunk idx nodes
  {{ patch_and_reboot(idx) }}
{% endfor %}

# Set status to false if enable maintenance mode succeded
orch-command-disable-maintenance-mode-splunk-cm:
  cmd.run:
    - name: curl -k -sS -X POST -u $rest_user:"$rest_user_pass" -d mode=false https://$splunk_api_url/$splunk_api_path | $splunk_api_filter
    - env:
        - rest_user: {{ config.splunk.admin_user }}
        - rest_user_pass: {{ config.splunk.current_admin_pass }}
        - splunk_api_url: {{ config.splunk.splunk_cm_uri }}:{{ config.splunk.splunk_mgmt_port }}
        - splunk_api_path: 'services/cluster/master/control/default/maintenance?output_mode=json'
        - splunk_api_filter: 'jq .'
    - output_loglevel: quiet
    - onchanges:
      - cmd: orch-command-enable-maintenance-mode-splunk-cm

