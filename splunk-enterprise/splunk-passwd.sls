# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Reset Splunk admin password if changed
command-update-splunk-admin-pass:
  cmd.run:
    - name: >- 
         {{ config.splunk.base_dir }}/bin/splunk edit user {{ config.splunk.admin_user }} -password "$current_admin_pass"
         -auth {{ config.splunk.admin_user }}:"$old_admin_pass"
    - env:
      - current_admin_pass: {{ config.splunk.current_admin_pass }}
      - old_admin_pass: {{ config.splunk.old_admin_pass }}
    - hide_output: True
    - output_loglevel: quiet
    - runas: splunk
    - require:
      - pkg: package-install-splunk
      - service: service-splunk
    - unless: >- 
         grep $(python3 -c "import crypt; print(crypt.crypt('{{ config.splunk.current_admin_pass }}',
         '$(awk -F'[:$]' '/{{ config.splunk.admin_user }}/ {print "$6$" $5 "$"}' {{ config.splunk.base_dir }}/etc/passwd)'))") 
         {{ config.splunk.base_dir }}/etc/passwd

