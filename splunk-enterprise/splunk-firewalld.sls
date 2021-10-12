# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}
{% if config.firewall.firewalld.status == 'Active' %}

# add some firewall magic
include:
  - firewall.firewalld

{% elif config.firewall.firewalld.status == 'InActive' %}

# If no configuration is imported disable firewalld
service-firewalld:
  service.dead:
    - name: firewalld
    - enable: False
    - unless: systemctl is-active firewalld |grep inactive

{% endif %}

