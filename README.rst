.. _readme:

Splunk Cluster Commander
========================
A salt formula for setting up and maintaining Splunk Enterprise on RHEL or Debian based systems.  

Configure clustered deployments as well as single standalone deployments using this formula.

Deploy splunk apps and orchestrate reboots required by OS patching, which can be used seperately.

All your logs our belong to splunk but everything tastes better with a bit of salt.  

.. contents:: **Table of Contents**
      :depth: 1

Available states
----------------

.. contents::
    :local:

``splunk-enterprise``
^^^^^^^^^^^^^^^^^^^^^
*Meta-state (This is a state that includes other states)*.

Installs **splunk-enterprise** and it's requirements,  
manages configuration files, and starts the service.

``splunk-enterprise.disable-thp``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Setup and manage a service to disable transparent hugepages.

``splunk-enterprise.splunk-kernel``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Setup resource limits, swappiness, max_mem count, disables ipv6,  
and manage tuned on RHEL based systems.

``splunk-enterprise.splunk-package``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Install splunk package from a local or remote source  
and configure optional pip package installs

``splunk-enterprise.splunk-user``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Manage splunk user account and configure sudoer configuration  
that allows splunk to start/stop/restart the Splunkd.service.

``splunk-enterprise.splunk-config``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Manage configuration files for splunk.

``splunk-enterprise.splunk-cluster``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Manage configuration files for splunk clustering.  
This supports indexer clusters as well as search head clusters.

``splunk-enterprise.splunk-firewalld``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Manage firewalld service on RHEL systems.  
**Currently only disables the service**

``splunk-enterprise.splunk-service``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Finalize splunk install by enabling boot-start, setting default permissions,  
and manage the splunk service on RHEL/Debian systems.

``splunk-enterprise.splunk-passwd``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Update the splunk admin password during setup but also can be called directly.

``splunk-enterprise.splunk-apps``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
**Only run this on the deployment server.**  
Manage splunkbase apps and/or custom apps using a versioned deployment system.

``splunk-enterprise.orch.orch-patch-and-reboot-member``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
This state runs an orchestration to patch and reboot splunk clustered nodes.
Call this with `salt-run state.orchestrate splunk-enterprise.orch.orch-patch-and-reboot-member`
