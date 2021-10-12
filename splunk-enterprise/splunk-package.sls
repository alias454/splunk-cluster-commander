# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "splunk-enterprise/map.jinja" import host_lookup as config with context %}

# Install prereqs for Splunk systems
package-install-prereqs-splunk:
  pkg.installed:
    - pkgs:
       - python3-pip
       - python3-pyOpenSSL
    - refresh: True

# Install/upgrade pip
pip-package-pip-splunk:
  pip.installed:
    - names:
       - pip
       - setuptools
    - upgrade: True
    - bin_env: {{ config.package.python_pip_cmd }}
    - user: root
    - reload_modules: True
    - require:
      - pkg: package-install-prereqs-splunk

# Install common utils using Pip
pip-package-install-common-pkg-splunk:
  pip.installed:
    - names:
      #- boto3
      #- awscli
      - python-dateutil
    - upgrade: True
    - bin_env: {{ config.package.python_pip_cmd }}
    - user: root
    - reload_modules: True
    - require:
      - pip: pip-package-pip-splunk

# Set package_source based on where the splunk package comes from
{% if config.package.install_type == 'download' %}
  {% set package_source = config.package.base_url + '/' + config.package.version + '/' + config.package.platform + '/' + config.package.file_name %}
{% elif config.package.install_type == 'local' %}
  {% set package_source = 'salt://splunk-enterprise/files/' + config.package.file_name %}
{% endif %}

# Install Splunk
package-install-splunk:
  pkg.installed:
    - sources:
      - {{ config.package.package_name }}: {{ package_source }}
    - refresh: True
    - skip_verify: {{ config.package.skip_verify }}
    - onchanges_in:
      - grains: grains-set-restart-status
      - cmd: command-restart-splunk

