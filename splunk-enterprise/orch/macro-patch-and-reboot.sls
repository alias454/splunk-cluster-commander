# -*- coding: utf-8 -*-
# vim: ft=sls

# Patch and reboot macro
{% macro patch_and_reboot(node, service='Splunkd.service') %}
# Update minion seperately and restart the service
orch-function-update-minion-{{ node }}:
  salt.function:
    - name: cmd.run
    - tgt: {{ node }}
    - arg:
      - salt-call --local pkg.upgrade name=salt-minion && systemctl restart salt-minion
    - timeout: 30
    - kwarg:
        bg: True

# Wait for up to 5 minutes before timing out
orch-wait-for-minion-restart-{{ node }}:
  salt.wait_for_event:
    - name: salt/minion/{{ node }}/start
    - id_list:
      - {{ node }}
    - timeout: 300
    - onchanges:
      - salt: orch-function-update-minion-{{ node }}

# Update os using uptodate state from update.sls
orch-state-update-os-{{ node }}:
  salt.state:
    - tgt: {{ node }}
    - sls:
      - {{ sls_path |replace('_', '.') }}.update
    - timeout: 600
    - require:
      - salt: orch-wait-for-minion-restart-{{ node }}

# Reboot the host if os update was succesful
orch-function-reboot-after-update-{{ node }}:
  salt.function:
    - name: system.reboot
    - arg: [1] # waits 1 minute 
    - tgt: {{ node }}
    - onchanges:
      - salt: orch-state-update-os-{{ node }}

# Wait for up to 10 minutes before timing out
orch-wait-for-reboot-{{ node }}:
  salt.wait_for_event:
    - name: salt/minion/{{ node }}/start
    - id_list:
      - {{ node }}
    - timeout: 600
    - onchanges:
      - salt: orch-function-reboot-after-update-{{ node }}

# Check node is up
orch-function-check-service-started-{{ node }}:
  salt.function:
    - name: service.start
    - tgt: {{ node }}
    - arg:
      - {{ service }}
    #- unless:
      #- systemctl status {{ service }}
    - require:
      - salt: orch-wait-for-reboot-{{ node }}

{% endmacro %}

