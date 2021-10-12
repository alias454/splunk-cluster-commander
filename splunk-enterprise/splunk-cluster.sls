# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

###########################################
#========  Setup Splunk Cluster  =========#
###########################################

#### Configuration for content length settings
{% if config.splunk.server_role in [ 'cluster-master', 'search-head', 'indexer' ] %}

# Default content length is 2147483648 bytes (2GB)
ini-add-splunk-httpserver-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        httpServer:
          max_content_length: '{{ config.splunk.httpserver_max_content_length }}'
    - onchanges_in:
      - grains: grains-set-restart-status

{% endif %}

#### Configuration for non license master instances
{% if config.splunk.server_role not in [ 'standalone', 'license-master' ] %}

# Add info for license master in the license section
ini-add-splunk-license-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        license:
          master_uri: 'https://{{ config.splunk.splunk_lm_uri }}:{{ config.splunk.splunk_mgmt_port }}'
    - onchanges_in:
      - grains: grains-set-restart-status

{% endif %}

#### Do not deploy on standalone instances or indexers
{% if config.splunk.server_role not in [ 'standalone', 'indexer' ] %}

# Manage /opt/splunk/etc/system/local/outputs.conf
{{ config.splunk.base_dir }}/etc/system/local/outputs.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/outputs.conf.jinja
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

{% endif %}

#### Do not deploy on standalone instances, indexers, or the deployment server itself
{% if config.splunk.server_role not in [ 'standalone', 'indexer', 'deployment-server' ] %}

# Manage /opt/splunk/etc/system/local/deploymentclient.conf
{{ config.splunk.base_dir }}/etc/system/local/deploymentclient.conf:
  file.managed:
    - source: salt://splunk-enterprise/files/deploymentclient.conf.jinja
    - template: jinja
    - user: splunk
    - group: splunk
    - mode: '0640'
    - onchanges_in:
      - grains: grains-set-restart-status

{% endif %}

###########################################
#========   Search Heads Setup   =========#
###########################################

#### Only deploy to the search heads
{% if config.splunk.server_role in [ 'search-head' ] %}

# Manage /opt/splunk/etc/system/local/distsearch.conf
# Bundle replication size default is 2048
ini-add-splunk-replicationSettings-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/distsearch.conf
    - separator: '='
    - strict: False
    - sections:
        replicationSettings:
          maxBundleSize: '{{ config.splunk.distsearch_maxBundleSize }}'
    - onchanges_in:
      - grains: grains-set-restart-status

# Add info for search heads in the clustering section
ini-add-splunk-search-head-cluster-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        general:
          site: '{{ config.splunk.cluster.search_site }}'
        clustering:
          mode: 'searchhead'
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
          master_uri: 'https://{{ config.splunk.splunk_cm_uri }}:{{ config.splunk.splunk_mgmt_port }}'
          multisite: '{{ config.splunk.cluster.multisite }}'
    - unless:
      - grep '{{ config.splunk.shcluster.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
    - watch_in:
      - file: comment-sh-clustering-pass4SymmKeyCheck-value

# Comment out the pass4SymmKey hash check line
comment-sh-clustering-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.cluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.cluster.pass4SymmKey | sha256 }}

# Add replication port to end of file
add-sh-clustering-replication-port:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - append_if_not_found: True
    - pattern: |
        ^[replication_port.*]$
    - repl: |
        
        [replication_port://{{ config.splunk.shcluster.replication_port }}]

{% if config.splunk.shcluster.use_shcluster == 'True' %}
# Add info for search heads in the shclustering section
ini-add-splunk-search-head-shcluster-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        shclustering:
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
          shcluster_label: '{{ config.splunk.shcluster.label }}'
          conf_deploy_fetch_url: 'https://{{ config.splunk.splunk_ds_uri }}:{{ config.splunk.splunk_mgmt_port }}'
          mgmt_uri: https://{{ grains['fqdn'] }}:{{ config.splunk.splunk_mgmt_port }}
          replication_factor: '{{ config.splunk.shcluster.replication_factor }}'
          disabled: '0'
    - unless:
      - grep '{{ config.splunk.shcluster.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
      - grep '{{ config.splunk.splunk_ds_uri }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
    - watch_in:
      - file: comment-sh-shclustering-pass4SymmKeyCheck-value

# Comment out the pass4SymmKey hash check line
comment-sh-shclustering-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.shcluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.shcluster.pass4SymmKey | sha256 }}

{% endif %}
{% endif %}

###########################################
#===========  Indexers Setup  ============#
###########################################

#### Only deploy to the indexers
{% if config.splunk.server_role in [ 'indexer' ] %}

# Add info for indexer in the general section, and clustering section
ini-add-splunk-indexer-sections:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        general:
          parallelIngestionPipelines: '{{ config.splunk.parallelIngestionPipelines }}' # Set parallel Ingestion Pipeline value for indexers
        clustering:
          mode: 'slave'
          master_uri: 'https://{{ config.splunk.splunk_cm_uri }}:{{ config.splunk.splunk_mgmt_port }}'
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
    - unless:
      - grep '{{ config.splunk.splunk_cm_uri }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
      - grep '{{ config.splunk.cluster.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
    - watch_in:
      - file: comment-idx-clustering-pass4SymmKeyCheck-value

# Comment out the pass4SymmKey hash check line
comment-idx-clustering-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.cluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.cluster.pass4SymmKey | sha256 }}

# Add replication port to end of file
add-idx-clustering-replication-port:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - append_if_not_found: True
    - pattern: |
        ^[replication_port.*]$
    - repl: |
        
        [replication_port://{{ config.splunk.cluster.replication_port }}]

{% endif %}

###########################################
#========  Cluster Master Setup  =========#
###########################################

#### Only deploy to cluster master
{% if config.splunk.server_role in [ 'cluster-master' ] %}

# Manage /opt/splunk/etc/apps/org_cm_base/local/server.conf in app/local
{{ config.splunk.base_dir }}/etc/apps/org_cm_base/local/server.conf:
  file.managed:
    - makedirs: True
    - show_changes: False
    - output_loglevel: quiet
    - user: splunk
    - group: splunk
    - mode: '0640'
    - contents: |
        [indexer_discovery]
        pass4SymmKey = {{ config.splunk.cluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.cluster.pass4SymmKey | sha256 }}
        indexerWeightByDiskCapacity = true
    - unless: >-
        grep '{{ config.splunk.cluster.pass4SymmKey | sha256 }}'
        {{ config.splunk.base_dir }}/etc/apps/org_cm_base/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status

# Add info for the clustering section on the cluster master
ini-add-splunk-cm-clustering-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        clustering:
          mode: 'master'
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
          cluster_label: '{{ config.splunk.cluster.label }}'
          replication_factor: '{{ config.splunk.cluster.replication_factor }}'
          multisite: '{{ config.splunk.cluster.multisite }}'
          available_sites: '{{ config.splunk.cluster.available_sites }}'
          site_replication_factor: '{{ config.splunk.cluster.site_replication_factor }}'
          site_search_factor: '{{ config.splunk.cluster.site_search_factor }}'
          restart_timeout: '{{ config.splunk.cluster.restart_timeout }}'
    - unless:
      - grep '{{ config.splunk.cluster.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
    - watch_in:
      - file: comment-cm-clustering-pass4SymmKeyCheck-value

# Comment out the pass4SymmKey hash check line
comment-cm-clustering-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.cluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.cluster.pass4SymmKey | sha256 }}

{% endif %}

###########################################
#======  Deployment Server Setup  ========#
###########################################

#### Only deploy to deployment server
{% if config.splunk.server_role in [ 'deployment-server' ] %}

# Manage /opt/splunk/etc/system/local/serverclass.conf
{{ config.splunk.base_dir }}/etc/system/local/serverclass.conf:
  file.managed:
    - makedirs: True
    - replace: False
    - user: splunk
    - group: splunk
    - mode: '0640'

{% if config.splunk.shcluster.use_deployer == 'True' %}
# Add info for the deployer shclustering section on the deployment-server
ini-add-splunk-ds-deployer-shcluster-section:
  ini.options_present:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - separator: '='
    - strict: False
    - sections:
        shclustering:
          pass4SymmKey: 'REPLACE_ME'
          pass4SymmKeyCheck: 'REPLACE_ME'
          shcluster_label: '{{ config.splunk.shcluster.label }}'
    - unless:
      - grep '{{ config.splunk.shcluster.pass4SymmKey | sha256 }}' {{ config.splunk.base_dir }}/etc/system/local/server.conf && exit 0
    - onchanges_in:
      - grains: grains-set-restart-status
    - watch_in:
      - file: comment-ds-deployer-pass4SymmKeyCheck-value

# Comment out the pass4SymmKeyCheck hash check line
comment-ds-deployer-pass4SymmKeyCheck-value:
  file.replace:
    - name: {{ config.splunk.base_dir }}/etc/system/local/server.conf
    - show_changes: False
    - backup: False
    - pattern: |
        ^pass4SymmKey = REPLACE_ME
        ^pass4SymmKeyCheck = REPLACE_ME
    - repl: |
        pass4SymmKey = {{ config.splunk.shcluster.pass4SymmKey }}
        #pass4SymmKeyCheck = {{ config.splunk.shcluster.pass4SymmKey | sha256 }}

{% endif %}
{% endif %}

