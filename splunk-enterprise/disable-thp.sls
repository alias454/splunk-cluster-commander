# -*- coding: utf-8 -*-
# vim: ft=sls

# Setup Disable transparent hugepages Unit file
/etc/systemd/system/disable-transparent-hugepages.service:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true
    - contents: |
        [Unit]
        Description=Disable Transparent Huge Pages (THP)
        DefaultDependencies=no
        After=sysinit.target local-fs.target
        Before=Splunkd.service
        
        [Service]
        Type=oneshot
        ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled"
        ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"
        RemainAfterExit=yes
        
        [Install]
        WantedBy=basic.target

# Make sure the service is running and enabled on boot
service-disable-transparent-hugepages:
  service.running:
    - name: disable-transparent-hugepages
    - enable: True
    - watch:
      - file: /etc/systemd/system/disable-transparent-hugepages.service
