#!/bin/sh
# Author: Carmen De Vito
# Description: Check to see if notification and checks are running for a particular core

# enable_notifications
# active_service_checks_enabled
# active_host_checks_enabled

#######################################################################
# Initialization:

: ${OCF_FUNCTIONS=${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs}
. ${OCF_FUNCTIONS}
: ${__OCF_ACTION=$1}

#######################################################################

meta_data() {
   cat <<END
<?xml version="1.0" ?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="Omd-HA" version="1.0">
   <version>1.0</version>
   <longdesc lang="en">
      This is the Omd-HA Resource Agent. The purpose of this script is to allow N number of running OMD processes that handle a common enviroment to coordinate which server
      should act as the notification box and which should run all of the checks. In the event of a server failure, one of the other nodes will be elected as the new active box
      to ensure continued monitoring.
   </longdesc>
   <shortdesc lang="en">OMD Active/Warm Standby Resource Agent</shortdesc>

   <parameters>
      <parameter name="state" unique="1">
         <longdesc lang="en">
            Destination to store resource state in.
         </longdesc>
         <shortdesc>State file</shortdesc>
         <content type="string" default="${HA_VARRUN}/Omd-HA-{OCF_RESOURCE_INSTANCE}.state" />
      </parameter>
   </parameters>
   <actions>
      <action name="start" timeout="20" />
      <action name="stop" timeout="20" />
      <action name="monitor" timeout="20" />
      <action name="meta-data" timeout="5" />
   </actions>
</resource-agent>

END
}

trap sigterm_handler TERM
sigterm_handler() {
   ocf_log info "They use TERM to bring us down. No such luck."
   return
}

omd_usage() {
   cat <<END
usage: $0 {start|stop|monitor|meta-data}
END
}

omd_start() {
   /omd/sites/<%=site %>/var/tmp/make_active.sh
   if [[ $? -ne 0 ]] ; then
      return $OCF_ERR_GENERIC
   else
      sleep 15
      return $OCF_SUCCESS
   fi
}

omd_stop() {
   /omd/sites/<%=site %>/var/tmp/make_standby.sh
   if [[ $? -ne 0 ]] ; then   
      return $OCF_ERR_GENERIC
   else
      sleep 15
      return $OCF_SUCCESS
   fi
}

omd_monitor() {
   ENABLE_NOTIFICATIONS=`grep 'enable_notifications' tmp/<%=core%>/status.dat | cut -f2 | cut -d'=' -f2`
   ACTIVE_SERVICE_CHECKS_ENABLED=`grep 'active_service_checks_enabled' tmp/<%=core%>/status.dat | cut -f2 | cut -d'=' -f2`
   ACTIVE_HOST_CHECKS_ENABLED=`grep 'active_host_checks_enabled' tmp/<%=core%>/status.dat | cut -f2 | cut -d'=' -f2`

   if [[ $ENABLE_NOTIFICATIONS -eq 0 && $ACTIVE_SERVICE_CHECKS_ENABLED -eq 0 && $ACTIVE_HOST_CHECK_ENABLED -eq 0 ]] ; then
        echo "ERROR - <%=core%> is in Passive Mode; enable_notifications=$ENABLE_NOTIFICATIONS,active_service_checks_enabled=$ACTIVE_SERVICE_CHECKS_ENABLED,active_host_checks_enabled=$ACTIVE_HOST_CHECKS_ENABLED"
        return $OFS_NOT_RUNNING
   elif [[ $ENABLE_NOTIFICATIONS -eq 1 && $ACTIVE_SERVICE_CHECKS_ENABLED -eq 1 && $ACTIVE_HOST_CHECK_ENABLED -eq 1 ]] ; then
        echo "OK - <%=core%> is in Active Mode; enable_notifications=$ENABLE_NOTIFICATIONS,active_service_checks_enabled=$ACTIVE_SERVICE_CHECKS_ENABLED,active_host_checks_enabled=$ACTIVE_HOST_CHECKS_ENABLED"
        return $OFS_SUCCESS
   else
        echo "UNKNOWN - <%=core%> is in an Unstable state; enable_notifications=$ENABLE_NOTIFICATIONS,active_service_checks_enabled=$ACTIVE_SERVICE_CHECKS_ENABLED,active_host_checks_enabled=$ACTIVE_HOST_CHECKS_ENABLED"
        return $OPS_ERR_GENERIC
   fi
}

: ${OCF_RESKEY_CRM_meta_interval=0}
: ${OCF_RESKEY_CRM_meta_globally_unique:="true"}

case $__OCF_ACTION in 
   meta-data)  meta-data
               exit $OCF_SUCCESS
               ;;
   start)      omd_start;;
   stop)       omd_stop;;
   monitor)    omd_monitor;;
   *)          dummy_usage
               exit $OCF_ERR_UNIMPLEMENTED
               ;;
esac

rc=$?
ocf_log debug "${OCF_RESOURCE_INSTANCE} $__OCF_ACTION : $rc"
exit $rc

