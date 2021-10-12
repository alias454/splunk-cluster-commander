# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Setup enable boot start for systemd based systems
command-enable-splunk-boot-start:
  cmd.run:
    - name: {{ config.splunk.base_dir }}/bin/splunk enable boot-start -user splunk -systemd-managed 1 --no-prompt --accept-license
    - creates: /etc/systemd/system/Splunkd.service
    - watch_in:
      - service: service-splunk
      - cmd: command-restart-splunk

# Set user and group on the entire install location
command-set-default-perms:
  cmd.run:
    - name: >-
        chmod -R o-rwx {{ config.splunk.base_dir }} &&
        chown -R splunk:splunk {{ config.splunk.base_dir }}
    - require:
      - cmd: command-enable-splunk-boot-start

# Set default acl for splunk on /var/log
command-set-default-acl-/var/log:
  cmd.run:
    - name: setfacl -Rm u:splunk:rX,d:u:splunk:rX /var/log
    - unless: getfacl /var/log |grep splunk

# Always clean restart status to get latest value set
{% if salt['grains.get']('splunk:needs_restart') == True %}
grains-clean-restart-status:
  grains.absent:
    - name: splunk:needs_restart
{% endif %}

# Set grain for restart status if changes have been made to prior states
grains-set-restart-status:
  grains.present:
    - name: splunk:needs_restart
    - value: True
    - onchanges:
      - cmd: command-enable-splunk-boot-start

# Make sure splunk service is enabled
service-splunk:
  service.enabled:
    - name: Splunkd.service

# Make sure service is running and restart if restart status grain is set
# This always runs when user-seed file is created or enable boot start runs
# When restart_service_after_state_change is false, no restart will happen
command-restart-splunk:
  cmd.run:
    - name: systemctl restart Splunkd.service
    - refresh: True
  {% if config.splunk.restart_service_after_state_change == 'True' %}
    - onchanges:
      - service: service-splunk
      - grains: grains-set-restart-status
  {% endif %}

# Clear restart status grain after splunk restart
grains-clear-restart-status:
  grains.absent:
    - name: splunk:needs_restart
    - reload_modules: True
    - onchanges:
      - cmd: command-restart-splunk

