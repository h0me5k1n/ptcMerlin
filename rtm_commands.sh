#!/bin/sh

#The first two lines of my .rtmcfg config are:
#api_key="your key here"
#api_secret="your secret here"
#You'll need this for all of the script.
api_url="https://api.rememberthemilk.com/services/rest/"
#I find json easier to work with, but you can remove it
#from here and in the api_key=$api_key&format=json&auth_token=$auth_token variable and you'll 
#get xml back. For json you'll need to install jq, because 
#this script relies heavily on it.

# run every 15 minutes
#cru a ptcMerlin "*/15 * * * * bash /mnt/routerusb/Transfer/ptcMerlin/ptcMerlin.sh process_overdue"

#authorization
#sign requests, pretty much all api calls need to be signed
#https://www.rememberthemilk.com/services/api/authentication.rtm
get_sig () {
  echo -n $api_secret$(echo "$1" | tr '&' '\n' | sort | tr -d '\n' | tr -d '=') | md5sum | cut -d' ' -f1
}

#https://www.rememberthemilk.com/services/api/authentication.rtm
#gets the frob and appends it to your .rtmcfg
get_frob () {
  method="rtm.auth.getFrob"
  args="method=$method&api_key=$api_key&format=json&auth_token=$auth_token"
  sig=$(get_sig "$args")

  echo method is $method
  echo args is $args
  echo sig is $sig
  echo url is $api_url?$args&api_sig=$sig

  x=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .frob | @text')
  echo "frob='$x'" >> .rtmcfg

}

#builds the URL for giving permissison for the app to 
#access your account. 
auth_app () {
  auth_url="http://www.rememberthemilk.com/services/auth/"
  perms="delete"
  args="api_key=$api_key&perms=$perms&frob=$frob"
  sig=$(get_sig "$args")
#  x-www-browser "$auth_url?$args&api_sig=$sig"
  echo " "
  Print_Output "false" "Open the following link and authorise the app..."
  Print_Output "false" "AUTH_URL is $auth_url?$args&api_sig=$sig"
  echo " "
}

#Once the window/tab/whatever is closed, this method is
#called to get the all important auth_token. Which is
#then appended to your .rtmcfg
get_token () {
  method="rtm.auth.getToken"
  args="method=$method&api_key=$api_key&format=json&auth_token=$auth_token&frob=$frob"
  sig=$(get_sig "$args")
  token=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.rsp | .auth | .token | @text')
  echo "auth_token='$token'" >> .rtmcfg
}

#bundles all the above steps
authenticate () {
  if [ "$(check_token)" = "token ok" ]; then
    Print_Output "false" "token is already valid"
    logger -t "$SCRIPTNAME" "token is already valid"
  else
    sed -i '/^frob=.*/d' "$SCRIPTDIR/.rtmcfg"
    sed -i '/^auth_token=.*/d' "$SCRIPTDIR/.rtmcfg"
    get_frob
    . $SCRIPTDIR/.rtmcfg
    echo frob is $frob
    
    auth_app
    sleep 2
    Print_Output "false" "waiting 30 seconds for browser to open and app to be authorised..."
    sleep 20 # wait for 20 seconds
    Print_Output "false" "10 seconds left to wait..."
    sleep 5 # wait for another 5 seconds 
    Print_Output "false" "5....."
    sleep 1 # wait for 1 second
    Print_Output "false" "4...."
    sleep 1 # wait for 1 second
    Print_Output "false" "3..."
    sleep 1 # wait for 1 second
    Print_Output "false" "2.."
    sleep 1 # wait for 1 second
    Print_Output "false" "1."
    sleep 1 # wait for 1 second
    Print_Output "false" "script continuing..."
    . $SCRIPTDIR/.rtmcfg
    echo frob is $frob
    
    get_token
    Print_Output "true" "authorisation complete"
    logger -t "$SCRIPTNAME" "authorisation complete"
  fi
}

#this is to check if your auth_token is valid
#use this to troubleshoot if the authentication isn't working.
check_token () {
  check="token fail"
  if [ ! -z "$auth_token" ]; then
    method="rtm.auth.checkToken"
    args="method=$method&api_key=$api_key&format=json&auth_token=$auth_token"
    sig=$(get_sig "$args")
    check=$(curl -s "$api_url?$args&api_sig=$sig" | jq -r '.[] | .stat')
    if [ "$check" = "ok" ]; then
      check="token ok"
      logger -t "$SCRIPTNAME" "$check"
    else
      check="token fail"
      logger -t "$SCRIPTNAME" "$check"
    fi
  else
    echo "auth_token not found. authorize probably required"
  fi
  echo "$check"
}

#Grab the tasks and save the json to tmp
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.getList.rtm
tasks_getList_all () {
  method="rtm.tasks.getList"
  args="method=$method&api_key=$api_key&format=json&auth_token=$auth_token"
  sig=$(get_sig "$args")
#  echo getting all tasks
#  curl -s "$api_url?$args&api_sig=$sig" | jq 
  RESPONSE=$(curl -s "$api_url?$args&api_sig=$sig" | jq --compact-output '.rsp.tasks.list[].taskseries[]? | [.id, .name, .task[0].due, .task[0].has_due_time, .task[0].completed, .task[0].deleted, .task[0].participants, .tags[]]')
  remove_square_brackets "$RESPONSE"
}

#Grab the tasks and save the json to tmp
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.getList.rtm
tasks_getList_open () {
  method="rtm.tasks.getList"
  args="method=$method&api_key=$api_key&format=json&auth_token=$auth_token&filter=status:incomplete"
  sig=$(get_sig "$args")
#  echo getting open tasks
  RESPONSE=$(curl -s "$api_url?$args&api_sig=$sig" | jq --compact-output '.rsp.tasks.list[].taskseries[]? | [.id, .name, .task[0].due, .task[0].has_due_time, .task[0].completed, .task[0].deleted, .task[0].participants, .tags[]]')
  remove_square_brackets "$RESPONSE"
}

remove_square_brackets() {
  echo -e ".id,.name,.task[0].due,.task[0].has_due_time,.task[0].completed,.task[0].deleted,.task[0].participants,.tags[]" > DATA.txt
  echo "${1}" | sed 's/^\[//g' | sed 's/\]$//g' >> DATA.txt
#  echo "$1" | sed 's/^\[//' | sed 's/\]$/\n/g'
#  echo "$1"
}

current_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

check_overdue() {
  Print_Output "false" "checking for overdue tasks..."
  unset OVERDUE_TAGS
  tasks_getList_open
  CURRENTUTC=$(current_utc)
  # create the OVERDUE_ALL.txt file in case nothing is written to it
  touch OVERDUE_ALL.txt
  # read and process only overdue tasks
  while IFS=, read -r id name due has_due_time completed deleted participants tags
    do
    # if due is not blank, exclude the header and the due date has passed
    if [ $due != "" -a $due != ".task[0].due" -a $due \< \"$CURRENTUTC\" ]; then 
#      Print_Output "false" "OVERDUE task $id named $name is due on ${due} and has the following tags - ${tags} - and the following participants - ${participants}"
#      Print_Output "false" "task ${id} has no due date"
#    else
#      Print_Output "false" "OVERDUE task $id named $name is due on ${due} and has the following tags - ${tags} - and the following participants - ${participants}"
#      TAGS_TEMP=$(echo $tags | sed '/\[//' | sed '/\]//' | sed '/"//' | sed '/,/ /')
      TAGS_TEMP="$(echo $tags | sed 's/^\[//g' | sed 's/\]$//g' | sed 's/"//g' | sed 's/,/ /g')"
#      Print_Output "false" "$TAGS_TEMP"
      # keep only unique tags
      OVERDUE_TAGS=$(echo "${OVERDUE_TAGS} $TAGS_TEMP" | xargs -n1 | sort -u | xargs)
      log_all_overdue
    fi
    done < DATA.txt
  if [ -z "$OVERDUE_TAGS" ]; then
    Print_Output "false" "no overdue tags"
    PrintLog "no overdue tags"
  else
    Print_Output "false" "OVERDUE_TAGS are $OVERDUE_TAGS"
    PrintLog "OVERDUE_TAGS are $OVERDUE_TAGS"
  fi
}

log_all_overdue() {
  # split the tags and write a line for each

  for each_tag in $TAGS_TEMP
  do
    echo "$id|$name|$due|$each_tag" | sed 's/"//g' >> OVERDUE_ALL.txt
  done
}

log_oldest_unique_tag_overdue() {
  Print_Output "false" "checking oldest overdue tasks by tag..."
  # remove data file if it exists
  [ -e OVERDUE_OLDEST_UNIQUE.txt ] && rm OVERDUE_OLDEST_UNIQUE.txt
  # create new file to process and find oldest overdue task for each tag
  cat OVERDUE_ALL.txt > OVERDUE_OLDEST.txt
  # sort by due date older to newer 
  sort -k3 -t '|' -o OVERDUE_OLDEST.txt OVERDUE_OLDEST.txt
  # find unique tags in the file
  UNIQUE_OVERDUE_TAGS="$(awk -F '|' '{print $4}' OVERDUE_OLDEST.txt | sort -u)"
  # echo UNIQUE_OVERDUE_TAGS are $UNIQUE_OVERDUE_TAGS
  # process the file to only keep the oldest task for each tag
  for each_unique_tag in $UNIQUE_OVERDUE_TAGS
  do
    cat OVERDUE_OLDEST.txt | grep -m1 "$each_unique_tag$" >> OVERDUE_OLDEST_UNIQUE.txt
  done

  # output the number of unique overdue tasks
  if [ -e OVERDUE_OLDEST_UNIQUE.txt ]; then
    NO_UNIQUE_OVERDUE_TASKS=$(wc -l OVERDUE_OLDEST_UNIQUE.txt | awk '{print $1}')
    Print_Output "false" "$NO_UNIQUE_OVERDUE_TASKS unique overdue tasks found..."
    PrintLog "$NO_UNIQUE_OVERDUE_TASKS unique overdue tasks found..."
  else 
    NO_UNIQUE_OVERDUE_TASKS=0
    Print_Output "false" "no unique overdue tasks found..."
    PrintLog "no unique overdue tasks found..."
    touch OVERDUE_OLDEST_UNIQUE.txt
  fi
}

# check for cfg
checkForConfig() {
  if [ -e "$SCRIPTDIR/.rtmcfg" ]; then
    . $SCRIPTDIR/.rtmcfg
  else
    Print_Output "false" "no .rtmcfg file exists. run script with authorize parameter"
    PrintLog "no .rtmcfg file exists. run script with authorize parameter"
    exit 1
  fi
}
