# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Only run this on the dpeloyment server.
# It can be called directly or invoked from the init.sls

# Set the reload path once for the entire sls file
{% set reload_path = config.splunk.base_dir + '/etc/deployment-apps' %}

# Set the source path once for the entire sls file
{% set source_path = 'splunk-enterprise/files/packages' %}

# Import yaml file with list of packages to deploy
{% import_yaml source_path + '/custom_packages.yaml' as apps %}

# Setup macro for app/add-on deployments
{% macro deploy_app(deploy_type, deploy_type_path, app_dir, app_name, app_ver) %}
{% set deploy_title = 'app-' + app_dir | replace('_', '-') %}
{% set deploy_path = config.splunk.base_dir + '/etc/' + deploy_type_path %}

# Deploy the app on the dpeloyment server
deploy-{{ deploy_type }}-{{ deploy_title }}:
  file.recurse:
    - name: {{ deploy_path }}/{{ app_dir }}
    - source: salt://{{ source_path }}/{{ app_dir }}
    - show_changes: False
    - output_loglevel: quiet
    - template: jinja
    - user: splunk
    - group: splunk
    - dir_mode: '0750'
    - file_mode: '0640'
    - include_empty: true
    - clean: true
    - exclude_pat:
      - "*.pyc"
    - unless: >-
       grep {{ app_ver }} {{ deploy_path }}/{{ app_dir }}/.version && exit 0

# Check for custom overrides and apply them
{% if salt['cp.list_master_dirs'](prefix=source_path + '/app_override/' + deploy_type + '/' + app_dir) %}
override-{{ deploy_type }}-{{ deploy_title }}:
  file.recurse:
    - name: {{ deploy_path }}/{{ app_dir }}
    - source: salt://{{ source_path }}/app_override/{{ deploy_type }}/{{ app_dir }}
    - show_changes: False
    - output_loglevel: quiet
    - template: jinja
    - user: splunk
    - group: splunk
    - dir_mode: '0750'
    - file_mode: '0640'
    - include_empty: true
    - require:
      - file: deploy-{{ deploy_type }}-{{ deploy_title }} 
    - onchanges_in:
      - file: file-create-reload-status-{{ deploy_type }}-{{ deploy_title }}
{% endif %}

# Create a version.txt file inside the application directory
add-{{ deploy_type }}-version-file-{{ app_dir | replace("_", "-") }}:
  file.managed:
    - name: {{ deploy_path }}/{{ app_dir }}/.version
    - user: splunk
    - group: splunk
    - mode: '0640'
    - contents: |
        [app]
        version = {{ app_ver }}
    - onchanges:
      - file: deploy-{{ deploy_type }}-{{ deploy_title }} 

# Find .sh files and make sure they are executable
command-set-executable-scripts-{{ deploy_type }}-{{ deploy_title }}:
  cmd.run:
    - name: find {{ deploy_path }}/{{ app_dir }}/ -type f -name *.sh -exec chmod 750 {} \;
    - runas: splunk
    - onchanges:
      - file: deploy-{{ deploy_type }}-{{ deploy_title }} 

# Create reload status file
file-create-reload-status-{{ deploy_type }}-{{ deploy_title }}:
  file.touch:
    - name: {{ reload_path }}/.reload
    - runas: splunk
    - onchanges:
      - file: deploy-{{ deploy_type }}-{{ deploy_title }} 
    - unless: |
        test -f {{ reload_path }}/.reload && exit 0

{% endmacro %}

# Setup macro for removing apps/add-ons
{% macro remove_app(deploy_type, deploy_type_path, app_dir) %}
{% set deploy_title = 'app-' + app_dir | replace('_', '-') %}
{% set deploy_path = config.splunk.base_dir + '/etc/' + deploy_type_path %}

# Remove the app from the dpeloyment server
remove-{{ deploy_type }}-{{ deploy_title }}:
  file.absent:
    - name: {{ deploy_path }}/{{ app_dir }}
    - onlyif: |
        test -d {{ deploy_path }}/{{ app_dir }} && exit 0
    - onchanges_in:
      - file: file-create-reload-status-{{ deploy_type }}-{{ deploy_title }}

# Create reload status file
file-create-reload-status-{{ deploy_type }}-{{ deploy_title }}:
  file.touch:
    - name: {{ reload_path }}/.reload
    - runas: splunk
    - onchanges:
      - file: remove-{{ deploy_type }}-{{ deploy_title }} 
    - unless: |
        test -f {{ reload_path }}/.reload && exit 0

{% endmacro %}

# Iterate through the list of packages from the imported yaml file
{% for app in apps.splunk_packages %}

# Set deploy type, which is one of deployer or deployment
{% set deployer = 'False' %}
{% set deployment = 'False' %}
{% if 'yes' in [ app.indexer, app.heavy_forwarder, app.universal_forwarder ] %}
  {% set deployment = 'True' %}
{% endif %}

{% if 'yes' in [ app.search_head ] %}
  {% if config.splunk.shcluster.use_deployer == 'True' %}
    {% set deployer = 'True' %}
  {% else %}
    {% set deployment = 'True' %}
  {% endif %}
{% endif %}

# Put apps in the right place when using the standard deployment process
{% if deployment == 'True' %}
  {% if app.status == 'enable' %}
    # deploy_app(deploy_type, deploy_type_path, app_dir, app_name, app_ver)
    {{ deploy_app('deployment', 'deployment-apps', app.package.deployment_folder, app.name, app.package.version) }}
  {% elif app.status == 'remove' %}
    # deploy_app(deploy_type, deploy_type_path, app_dir)
    {{ remove_app('deployment', 'deployment-apps', app.package.deployment_folder) }}
  {% endif %}
{% endif %}

# Put apps in the right place when using the deployer for shclustering
{% if deployer == 'True' %}
  {% if app.status == 'enable' %}
    # deploy_app(deploy_type, deploy_type_path, app_dir, app_name, app_ver)
    {{ deploy_app('deployer', 'shcluster/apps', app.package.deployment_folder, app.name, app.package.version) }}
  {% elif app.status == 'remove' %}
    # deploy_app(deploy_type, deploy_type_path, app_dir)
    {{ remove_app('deployer', 'shcluster/apps', app.package.deployment_folder) }}
  {% endif %}
{% endif %}

{% endfor %}

# Manage the serverclass.conf file
file-manage-splunk-serverclass-conf:
  file.managed:
    - name: {{ config.splunk.base_dir }}/etc/system/local/serverclass.conf
    - source: salt://{{ source_path }}/serverclass.conf.jinja
    - template: jinja
    - user: splunk
    - group: splunk
    - mode: '0640'

# Reload Splunk deployment server if changes
command-reload-splunk-deployment-server:
  cmd.run:
    - name: {{ config.splunk.base_dir }}/bin/splunk reload deploy-server -auth {{ config.splunk.admin_user }}:"$current_admin_pass"
    - env:
      - current_admin_pass: {{ config.splunk.current_admin_pass }}
    - refresh: True
    - hide_output: True
    - output_loglevel: quiet
    - runas: splunk
    - require:
      - file: file-manage-splunk-serverclass-conf
    - onlyif: |
        test -f {{ reload_path }}/.reload && exit 0

# Clear reload status file after splunk reload
file-clear-reload-status:
  file.absent:
    - name: {{ reload_path }}/.reload
    - onchanges:
      - cmd: command-reload-splunk-deployment-server
    - onlyif: |
        test -f {{ reload_path }}/.reload && exit 0

