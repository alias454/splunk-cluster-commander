# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Configure tuned for RHEL based systems
{% if salt.grains.get('os_family') == 'RedHat' %}
/etc/tuned/splunk/tuned.conf:
  file.managed:
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true
    - contents: |
        # Managed by Salt do not edit
        [main]
        include=throughput-performance
        
        [vm]
        transparent_hugepages=never

# Set the splunk tuned profile as default
command-set-splunk-tuned-profile:
  cmd.run:
    - name: tuned-adm profile splunk
    - require:
      - file: /etc/tuned/splunk/tuned.conf
    - unless: tuned-adm active |grep splunk
{% endif %}

# Create kernel override config for swappiness
# max_map_count, and ipv6 support
/etc/sysctl.d/10-Splunk_KernelOverride.conf:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - replace: False

# Set kernel override for vm.swappiness
sysctl-set-swappiness:
  sysctl.present:
    - name: vm.swappiness
    - value: {{ config.kernel.vm_swappiness }}
    - config: /etc/sysctl.d/10-Splunk_KernelOverride.conf
    - require:
      - file: /etc/sysctl.d/10-Splunk_KernelOverride.conf 

# Set kernel override for vm.max_map_count
sysctl-set-max-map-count:
  sysctl.present:
    - name: vm.max_map_count
    - value: {{ config.kernel.vm_max_map_count }}
    - config: /etc/sysctl.d/10-Splunk_KernelOverride.conf
    - require:
      - file: /etc/sysctl.d/10-Splunk_KernelOverride.conf 

# Set kernel override for ipv6 all
sysctl-set-ipv6-all-disable-ipv6:
  sysctl.present:
    - name: net.ipv6.conf.all.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/10-Splunk_KernelOverride.conf
    - require:
      - file: /etc/sysctl.d/10-Splunk_KernelOverride.conf 

# Set kernel override for ipv6 default
sysctl-set-ipv6-default-disable-ipv6:
  sysctl.present:
    - name: net.ipv6.conf.default.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/10-Splunk_KernelOverride.conf
    - require:
      - file: /etc/sysctl.d/10-Splunk_KernelOverride.conf 

# Set kernel override for ipv6 lo
sysctl-set-ipv6-lo-disable-ipv6:
  sysctl.present:
    - name: net.ipv6.conf.lo.disable_ipv6
    - value: 1
    - config: /etc/sysctl.d/10-Splunk_KernelOverride.conf
    - require:
      - file: /etc/sysctl.d/10-Splunk_KernelOverride.conf 

# Set resource limits for the splunk user
/etc/security/limits.d/90-splunk.conf:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        # Managed by Salt do not edit
        # Set resource limits for splunk user
        splunk soft nofile 64000
        splunk hard nofile 64000

        splunk soft nproc 32000
        splunk hard nproc 32000

