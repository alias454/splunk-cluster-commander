# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

include:
  - .disable-thp
  - .splunk-kernel
  - .splunk-package
  - .splunk-user
  - .splunk-config
  - .splunk-cluster
  - .{{ config.firewall.firewall_include }}
  - .splunk-service
  - .splunk-passwd
# Only run this on the deployment server.
# It can be called directly or invoked from this file(init.sls)
{% if config.splunk.server_role in [ 'deployment-server' ] %}
  - .splunk-apps
{% endif %}
