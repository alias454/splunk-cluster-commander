# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Only deploy to license master or a standard instance
{% if config.splunk.server_role in [ 'standalone', 'license-master' ] %}

# Manage /opt/splunk/etc/licenses/enterprise/Splunk.License.lic
{{ config.splunk.base_dir }}/etc/licenses/enterprise/{{ config.splunk.license_file }}:
  file.managed:
    - source: salt://splunk-enterprise/files/{{ config.splunk.license_file }}
    - makedirs: True
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

{% endif %}

# Do not deploy to indexer instances
{% if config.splunk.server_role not in [ 'indexer' ] %}

# Manage /opt/splunk/etc/system/local/alert_actions.conf
{{ config.splunk.base_dir }}/etc/system/local/alert_actions.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/alert_actions.conf.jinja
    - template: jinja
    - show_changes: False
    - output_loglevel: quiet
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

{% endif %}

# Copy initial template structure over then add ini section data
{{ config.splunk.base_dir }}/etc/system/local/server.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/server.conf.tpl
    - show_changes: False
    - output_loglevel: quiet
    - user: splunk
    - group: splunk
    - mode: '0640'
    - unless:
      - grep '{{ config.splunk.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
      - grep '{{ config.splunk.ssl.password | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0

# Manage /opt/splunk/etc/system/local/server.conf
ini-add-general-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        general:
          site: '{{ config.splunk.cluster.default_site }}'
          serverName: '{{ grains['fqdn'] }}'
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
        sslConfig:
          sslPassword: 'REPLACE_ME'
          sslPasswordCheck: 'REPLACE_ME'
        kvstore:
          storageEngine: '{{ config.splunk.kvstore_storageEngine }}'
    - unless:
      - grep '{{ config.splunk.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
      - grep '{{ config.splunk.ssl.password | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
      - service: service-splunk
    - watch_in:
      - file: comment-general-pass4SymmKeyCheck-value
      - file: comment-general-sslPasswordCheck-value

# Comment out the pass4SymmKey hash check line
comment-general-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.pass4SymmKey | sha256 }}

# Comment out the sslPassword hash check line
comment-general-sslPasswordCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^sslPassword = REPLACE_ME
        ^sslPasswordCheck = REPLACE_ME
    - repl: |
        sslPassword = {{ config.splunk.ssl.password }}
        #sslPasswordCheck = {{ config.splunk.ssl.password | sha256 }}

# Sets up the configuration for all instance types
# Manage /opt/splunk/etc/system/local/web.conf
{{ config.splunk.base_dir }}/etc/system/local/web.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/web.conf.jinja
    - template: jinja
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

# Sets up the configuration for all instance types
# Manage /opt/splunk/etc/system/local/inputs.conf
{{ config.splunk.base_dir }}/etc/system/local/inputs.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/inputs.conf.jinja
    - template: jinja
    - backup: False
    - replace: False
    - show_changes: False
    - output_loglevel: quiet
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

# Sets basic splunk auth for all instance types
# Manage /opt/splunk/etc/system/local/authentication.conf
{{ config.splunk.base_dir }}/etc/system/local/authentication.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/authentication.conf.jinja
    - template: jinja
    - output_loglevel: quiet
    - replace: False
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

