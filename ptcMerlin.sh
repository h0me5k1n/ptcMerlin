#!/bin/sh

# variables
SCRIPTNAME="$(basename $0)"
SCRIPTDIR="$(cd $(dirname $0) && pwd)"
vLOG="$SCRIPTDIR/${SCRIPTNAME%.*}.log"

#echo SCRIPTNAME is $SCRIPTNAME
#echo SCRIPTDIR is $SCRIPTDIR

cd "$SCRIPTDIR"

# Logging $1 = print to syslog, $2 = message to 
# print navigate to script directory
Print_Output(){
if [ "$1" = "true" ]; then
		logger -t "$SCRIPTNAME" "$2"
		printf "%s\n" "$2"
	else
		printf "%s\n" "$2"
	fi
}

PrintLog(){
  echo "[`date`] - ${*}" >> "${vLOG}"
  # truncate log file to 250 lines when 500 reached
  NO_LOGLINES=$(wc -l ${vLOG} | awk '{print $1}')
#  echo "lines in log file - $NO_LOGLINES"
  if [ "$NO_LOGLINES" -gt 500 ]; then
    sed -i '1,250d' "${vLOG}"
  fi
}

# show usage
COMMANDFILECHECK=$(ls $SCRIPTDIR | grep _commands.sh | sed 's/_commands.sh//' | tr '\n' ' ')
show_usage() {
  Print_Output "false" "Usage: $SCRIPTNAME [PLUGIN] {ACTION}"

  Print_Output "false" "### Valid options for PLUGIN:"
  Print_Output "false" "this should be the text from the \"???_commands.sh\" file and the \".???cfg\" file"
  Print_Output "false" "AVAILABLE \"commands\" files: $COMMANDFILECHECK"

  Print_Output "false" "### Valid options for ACTION:"
  Print_Output "false" "checktoken - check if api token is valid"
  Print_Output "false" "authorize - authorise api by generating a token"
  Print_Output "false" "get_all - query api for all tasks"
  Print_Output "false" "get_open - query api for all tasks"
  Print_Output "false" "check_overdue - query api for open, overdue tasks"
  Print_Output "false" "process_overdue - query for overdue tasks and act upon results"
  Print_Output "false" "cru_add - add cru entry to run automatically"
  Print_Output "false" "cru_del - remove cru entry"
  Print_Output "false" "autostart_enable - enable running at startup"
  Print_Output "false" "autostart_disable - disable running at startup"
  exit 1
}

# if no parameters passed, show the usage info
if [ $# -eq 0 ]; then
  show_usage
fi

# check if command and cfg files exist
if [ ! -f ${1}_commands.sh ] || [ ! -f .${1}cfg ]; then
  Print_Output "true" "command and cfg files not found for \"$1\" parameter"
  Print_Output "false" "check usage by running the script without parameters"
  exit 1
fi

# firmware specific
Firmware_Version_Check(){
  if which nvram >/dev/null; then
    if nvram get rc_support | grep -qF "am_addons"; then
      ASUS_FW_DETECTED="true"
      return 0
    else
      ASUS_FW_DETECTED="false"
      return 1
    fi
  else
    Print_Output "false" "ASUS firmware not detected"
    ASUS_FW_DETECTED="false"
  fi
}

# process overdue items
process_overdue() {
  Print_Output "false" "processing overdue tasks..."
  if [ "$ASUS_FW_DETECTED" = "true" ]; then
    # get current value of NVRAM vars to variable
    wrs_rulelist_ORIG="$(getNVRAM_data wrs_rulelist)"
    wrs_app_rulelist_ORIG="$(getNVRAM_data wrs_app_rulelist)"
  else
    # get current value of NVRAM vars to variable
    wrs_rulelist_ORIG="PASTE EXISTING CONTENT OF wrs_rulelist HERE FOR DEBUGGING SEPARATE FROM THE ROUTER"
    wrs_app_rulelist_ORIG="PASTE EXISTING CONTENT OF wrs_app_rulelist HERE FOR DEBUGGING SEPARATE FROM THE ROUTER"
  fi

  # get current value of NVRAM vars in new variable to be used for processing
  wrs_rulelist_NEW=$wrs_rulelist_ORIG
  wrs_app_rulelist_NEW=$wrs_app_rulelist_ORIG
  # find unique tags in tag2mac_lookup file
  UNIQUE_LOOKUP_TAGS="$(awk '{print $1}' tag2mac_lookup | sort -u)"
#  Print_Output "false" "UNIQUE_LOOKUP_TAGS are $UNIQUE_LOOKUP_TAGS"
  for each_unique_lookup_tag in $UNIQUE_LOOKUP_TAGS
  do
    if grep "$each_unique_lookup_tag" OVERDUE_OLDEST_UNIQUE.txt >/dev/null; then
      Print_Output "false" "macs related to $each_unique_lookup_tag should be BLOCKED"
      PrintLog "macs related to $each_unique_lookup_tag should be BLOCKED"
      for each_mac_address in $(grep "$each_unique_lookup_tag" tag2mac_lookup | awk '{print $2}')
      do
#        Print_Output "false" "$each_mac_address"
        Print_Output "false" "blocking $each_mac_address with tag $each_unique_lookup_tag"
#        wrs_rulelist_NEW=${wrs_rulelist_NEW/0>$each_mac_address/1>$each_mac_address}
#        wrs_app_rulelist_NEW=${wrs_app_rulelist_NEW/0>$each_mac_address/1>$each_mac_address}
        wrs_rulelist_NEW=$(echo $wrs_rulelist_NEW | sed -e "s/0>${each_mac_address}/1>${each_mac_address}/g")
        wrs_app_rulelist_NEW=$(echo $wrs_app_rulelist_NEW | sed -e "s/0>${each_mac_address}/1>${each_mac_address}/g")
      done
    else
      echo "macs related to $each_unique_lookup_tag should be UNBLOCKED"
      for each_mac_address in $(grep "$each_unique_lookup_tag" tag2mac_lookup | awk '{print $2}')
      do
#        Print_Output "false" "unblocking $each_mac_address with tag $each_unique_lookup_tag"
#        wrs_rulelist_NEW="${wrs_rulelist_NEW/1>$each_mac_address/0>$each_mac_address}"
#        wrs_app_rulelist_NEW="${wrs_app_rulelist_NEW/1>$each_mac_address/0>$each_mac_address}"
        wrs_rulelist_NEW=$(echo $wrs_rulelist_NEW | sed -e "s/1>${each_mac_address}/0>${each_mac_address}/g")
        wrs_app_rulelist_NEW=$(echo $wrs_app_rulelist_NEW | sed -e "s/1>${each_mac_address}/0>${each_mac_address}/g")
      done
    fi
  done

  # if there are changes to wrs nvram settings, write them and restart the services
#  DIFF_wrs=$(diff <(echo "$wrs_rulelist_ORIG") <(echo "$wrs_rulelist_NEW"))
#  DIFF_app=$(diff <(echo "$wrs_app_rulelist_ORIG") <(echo "$wrs_app_rulelist_NEW"))
# logging for debugging
#  echo "wrs_rulelist_ORIG" > diff.log
#  echo "$wrs_rulelist_ORIG" > diff.log
#  echo "wrs_rulelist_NEW" >> diff.log
#  echo "$wrs_rulelist_NEW" >> diff.log
#  echo "wrs_app_rulelist_ORIG" >> diff.log
#  echo "$wrs_app_rulelist_ORIG" >> diff.log
#  echo "wrs_app_rulelist_NEW" >> diff.log
#  echo "$wrs_app_rulelist_NEW" >> diff.log
  # if there are differences in the configurations after checking, apply changes
  if [ "$wrs_rulelist_ORIG" != "$wrs_rulelist_NEW" -o "$wrs_app_rulelist_ORIG" != "$wrs_app_rulelist_NEW" ]; then
    Print_Output "true" "applying changes to parental control settings due to task state"
    PrintLog "applying changes to parental control settings due to task state"
    if [ $ASUS_FW_DETECTED = "true" ]; then
      Print_Output "false" "writing nvram"
      PrintLog "writing nvram"
      nvram set wrs_rulelist="$wrs_rulelist_NEW"
      nvram set wrs_app_rulelist="$wrs_app_rulelist_NEW"
      Print_Output "false" "restarting wrs"
      PrintLog "restarting wrs"
      service "restart_wrs;restart_firewall"
    else
      Print_Output "false" "skipping actually making changes as non ASUS firmware detected"
      PrintLog "skipping actually making changes as non ASUS firmware detected"
    fi
  else
    Print_Output "false" "no changes required to parental control settings"
    PrintLog "no changes required to parental control settings"
  fi
}

# function to get value from NVRAM variable
getNVRAM_data(){
  nvram get $1
}

# cleanup script
cleanup() {
  [ -e DATA.txt ] && rm DATA.txt
  [ -e OVERDUE.txt ] && rm OVERDUE.txt
  [ -e OVERDUE_ALL.txt ] && rm OVERDUE_ALL.txt
  [ -e OVERDUE_OLDEST.txt ] && rm OVERDUE_OLDEST.txt
  [ -e OVERDUE_OLDEST_UNIQUE.txt ] && rm OVERDUE_OLDEST_UNIQUE.txt
  [ -e diff.log ] && rm diff.log
}

Auto_Cron() {
  if [ $ASUS_FW_DETECTED = "true" ]; then
    case $1 in
      create)
        STARTUPLINECOUNT=$(cru l | grep -c "${SCRIPTNAME}_${plugin}")
        if [[ "$STARTUPLINECOUNT" -eq 0 ]]; then
          cru a "${SCRIPTNAME}_${plugin}" "*/15 * * * * sh $SCRIPTDIR/$SCRIPTNAME $plugin process_overdue"
          Print_Output "true" "cru entry added for $plugin"
          PrintLog "cru entry added for $plugin"
        fi
      ;;
      delete)
        STARTUPLINECOUNT=$(cru l | grep -c "$SCRIPTNAME")
        if [[ "$STARTUPLINECOUNT" -gt 0 ]]; then
          cru d "${SCRIPTNAME}_${plugin}"
          Print_Output "true" "cru entry deleted for $plugin"
          PrintLog "cru entry deleted for $plugin"
        fi
      ;;
    esac
  else
    Print_Output "false" "cru entry not entered as non ASUS firmware detected"
    PrintLog "cru entry not entered as non ASUS firmware detected"
  fi
}

Auto_Startup(){
  if [ $ASUS_FW_DETECTED = "true" ]; then
    case $1 in
      create)
        if [ -f /jffs/scripts/services-start ]; then
          STARTUPLINECOUNT=$(grep -c '# '"$SCRIPTNAME" /jffs/scripts/services-start)
          if [ "$STARTUPLINECOUNT" -eq 0 ]; then
            echo "$SCRIPTDIR/$SCRIPTNAME $plugin cru_add &"' # '"$SCRIPTNAME" >> /jffs/scripts/services-start
            Print_Output "true" "auto startup for $plugin added to services-start"
            PrintLog "auto startup for $plugin added to services-start"
          else
            Print_Output "true" "auto startup for $plugin already exists in services-start"
            PrintLog "auto startup for $plugin already exists in services-start"
          fi
        else
          echo "#!/bin/sh" > /jffs/scripts/services-start
          echo "" >> /jffs/scripts/services-start
          echo "$SCRIPTDIR/$SCRIPTNAME cru_add &"' # '"$SCRIPTNAME" >> /jffs/scripts/services-start
          chmod 0755 /jffs/scripts/services-start
          Print_Output "true" "services-start created and auto startup for $plugin added"
          PrintLog "services-start created and auto startup for $plugin added"
        fi
      ;;
      delete)
        if [ -f /jffs/scripts/services-start ]; then
          STARTUPLINECOUNT=$(grep -c '# '"$SCRIPTNAME" /jffs/scripts/services-start)
          if [ "$STARTUPLINECOUNT" -gt 0 ]; then
            sed -i -e '/# '"$SCRIPTNAME"'/d' /jffs/scripts/services-start
            Print_Output "true" "auto startup for $plugin removed from services-start"
            PrintLog "auto startup for $plugin removed from services-start"
          fi
        fi
      ;;
    esac
  else
    Print_Output "false" "startup entry not entered as non ASUS firmware detected"
    PrintLog "startup entry not entered as non ASUS firmware detected"
  fi
}

checkForConfig() {
  if [ "$1" = "help" ]; then
    show_usage
  else
    plugin="$1"
    plugincfg="$SCRIPTDIR/.${plugin}cfg"
    plugincommands="$SCRIPTDIR/${plugin}_commands.sh"
    # check for cfg
    if [ ! -f "$plugincfg" ]; then
      Print_Output "false" "$plugincfg not found"
      PrintLog "$plugincfg not found"
      exit 1
    fi
    # check for commands
    if [ ! -f "$plugincommands" ]; then
      Print_Output "false" "$plugincommands not found"
      PrintLog "$plugincommands not found"
      exit 1
    fi
    Print_Output "false" "using $plugin configuration"
    PrintLog "using $plugin configuration"
    . ${plugincfg}
    . ${plugincommands}
  fi
}



# configuration selection
use_rtm() {
  Print_Output "false" "using rememberthemilk configuration"
  PrintLog "using rememberthemilk configuration"
  . $SCRIPTDIR/rtm_commands.sh
  # this loads the functions from the plugin script and the cfg file that contains the variables
  checkForConfig
}

use_quire() {
  Print_Output "false" "using quire configuration"
  PrintLog "using quire configuration"
  . $SCRIPTDIR/quire_commands.sh
  # this loads the functions from the plugin script and the cfg file that contains the variables
  checkForConfig
}

################
################
################
################

Firmware_Version_Check

PrintLog "$SCRIPTNAME started"
# change this to be defined on each run in future - default to rtm with this entry
#use_rtm
#use_quire
checkForConfig "$1"

### this is the start of the script
cleanup

#does the actions below. i should add a 'help' section.
#Note that it syncs your tasks everytime you add or 
#complete one. 
for i in "$@"
do
case $i in
  get_all)
    PrintLog "get_all option executing"
    checkForConfig
    tasks_getList_all
    Print_Output "false" "ALL tasks:"
    cat DATA.txt
  shift;;
  get_open)
    PrintLog "get_open option executing"
    checkForConfig
    tasks_getList_open
    Print_Output "false" "OPEN tasks:"
    cat DATA.txt
  shift;;
  authorize)
    PrintLog "authorize option executing"
    authenticate
  shift;;
  checktoken)
    PrintLog "checktoken option executing"
    check_token
  shift;;
  check_overdue)
    PrintLog "check_overdue option executing"
    check_overdue
  shift;;
  process_overdue)
    PrintLog "process_overdue option executing"
    checkForConfig
    check_overdue
    log_oldest_unique_tag_overdue
    process_overdue
  shift;;
  cru_add)
    PrintLog "adding schedule entry option executing"
    checkForConfig
    Auto_Cron create
  shift;;
  cru_del)
    PrintLog "removing schedule entry option executing"
    Auto_Cron delete
  shift;;
  autostart_enable)
    PrintLog "auto start entry option executing"
    Auto_Startup create
  shift;;
  autostart_disable)
    PrintLog "auto start entry option executing"
    Auto_Startup delete
  shift;;
  help)
    show_usage
    exit 1
esac
done

cleanup 

PrintLog "$SCRIPTNAME completed"
PrintLog "-----"
