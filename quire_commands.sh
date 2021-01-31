#!/bin/sh

#The first two lines of my .quirecfg config are:
#api_clientid="your client id here"
#api_secret="your secret here"
#You'll need this for all of the script.
api_url="https://quire.io/api"
#I find json easier to work with, but you can remove it
#from here and in the api_key=$api_key&format=json&auth_token=$auth_token variable and you'll 
#get xml back. For json you'll need to install jq, because 
#this script relies heavily on it.

if [ -z "$ProjectName" ]; then
  echo "ProjectName not set in ${plugincfg}"
  echo "you must manually add a single entry for ProjectName= in the cfg file"
  echo "you can find what needs to be entered by checking the project options in quire"
  echo "this can be found after the "https://quire.io/w/" text in the Project URL section"
  exit 1
fi

#authorization 
 
#builds the URL for giving permissison for the app to 
#access your account. 
auth_app () {
  auth_url="https://quire.io/oauth"
  args="client_id=$api_clientid"
#  x-www-browser "$auth_url?$args&api_sig=$sig"
  echo " "
  echo "AUTH_URL is $auth_url?$args"
  echo " "
  echo "you need to open the above link and use developer tools in chrome to record"
  echo "network activity to get the code from the header"
  echo "this appears in the \"confirm\" response header under \"location\""
  echo "this should be added to .quirecfg as a new line starting with api_code="
  echo " "
  # TODO - possibly add a command to capture the code and write it to the cfg file?
  read -p "Paste code: " api_code
  if [ -z "$api_code" ]
  then
    echo "api_code is empty"
    exit 1
  else
    echo "api_code='$api_code'" >> .quirecfg
  fi
}

get_code() {
  auth_url="https://quire.io/oauth"
    TOKENRESPONSE=$(curl -s --request POST \
  --url "$auth_url" \
  --data "grant_type=authorization_code" \
  --data "client_id=$api_clientid" \
  --data "client_secret=$api_secret" \
  --data "code=$api_code")

  args"client_id=$api_clientid&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code"
  url="$auth_url?$args"

}

refresh_code() {
  echo "attempting to refresh token"
  auth_url="https://quire.io/oauth"
  TOKENRESPONSE=$(curl -s --request POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --url "$auth_url/token" \
  --data "grant_type=refresh_token" \
  --data "client_id=$api_clientid" \
  --data "client_secret=$api_secret" \
  --data "refresh_token=$refresh_token")

  sed -i -e '/access_token/d' .quirecfg

  access_token=$(echo $TOKENRESPONSE | jq -r '.access_token | @text')
  
  echo "access_token='$access_token'" >> .quirecfg

}

#Once the window/tab/whatever is closed, this method is
#called to get the all important auth_token. Which is
#then appended to your .quirecfg
get_token () {
  TOKENRESPONSE=$(curl -s --request POST \
  --url "https://quire.io/oauth/token" \
  --data "grant_type=authorization_code" \
  --data "client_id=$api_clientid" \
  --data "client_secret=$api_secret" \
  --data "code=$api_code")

  ACCESSTOKEN=$(echo $TOKENRESPONSE | jq -r '.access_token | @text')
  REFRESHTOKEN=$(echo $TOKENRESPONSE | jq -r '.refresh_token | @text')
  
  echo "access_token='$ACCESSTOKEN'" >> .quirecfg
  echo "refresh_token='$REFRESHTOKEN'" >> .quirecfg
}

#bundles all the above steps
authenticate () {
  if [ "$(check_token)" = "token ok" ]; then
    Print_Output "false" "token is already valid"
    logger -t "$SCRIPTNAME" "token is already valid"
  else
    sed -i '/^refresh_token=.*/d' "$SCRIPTDIR/.quirecfg"
    sed -i '/^access_token=.*/d' "$SCRIPTDIR/.quirecfg"
    sed -i '/^api_code=.*/d' "$SCRIPTDIR/.quirecfg"
    . $SCRIPTDIR/.quirecfg
    
    auth_app
    
    Print_Output "false" "script continuing..."
    . $SCRIPTDIR/.quirecfg
    
    get_token
    # remove the api_code
    sed -i '/^api_code=.*/d' "$SCRIPTDIR/.quirecfg"

    Print_Output "true" "authorisation complete"
    logger -t "$SCRIPTNAME" "authorisation complete"
  fi
}

#this is to check if your auth_token is valid
#use this to troubleshoot if the authentication isn't working.
check_token () {
  check="token fail"
  if [ ! -z "$access_token" ]; then
    TOKENSTATE=$(curl -s -H "Authorization: Bearer $access_token" "$api_url/user/id/me" | jq -r '.oid')
    if [ "$TOKENSTATE" != "null" ]; then
      check="token ok"
      logger -t "$SCRIPTNAME" "$check"
    else
      # attempt to refresh the access_token and retry before failing
      refresh_code
      TOKENSTATE=$(curl -s -H "Authorization: Bearer $access_token" "$api_url/user/id/me" | jq -r '.oid')
      if [ $TOKENSTATE != "null" ]; then
        check="token ok"
        logger -t "$SCRIPTNAME" "$check"
      else
        check="token fail"
        logger -t "$SCRIPTNAME" "$check"
      fi
    fi
  else
    echo "access_token not found. authorize probably required"
  fi
  echo "$check"
}

####

#Get all boards of the given project by its ID.
get_projects(){
  PROJECTS=$(curl -s -H "Authorization: Bearer $access_token" "$api_url/project/list" | jq -r --compact-output '.[]? | [.id, .name]')
  echo "$PROJECTS" | sed 's/^\[//g' | sed 's/\]$//g'
}

#Get board oid of the given project by its name.
get_board_oid(){
#  ProjectName is taken from the cfg file
  BOARD_OID=$(curl -s -H "Authorization: Bearer $access_token" "$api_url/project/id/$ProjectName" | jq -r '.oid')
#  echo $BOARD_OID
}

#Get all root tasks of the given project or all subtasks of the given task.
get_board_tasks(){
  curl -s -H "Authorization: Bearer $access_token" "$api_url/task/list/$BOARD_OID" | jq
}

#Grab the tasks and save the json to tmp
tasks_getList_all() {
  get_board_oid
  RESPONSE=$(curl -s -H "Authorization: Bearer $access_token" "$api_url/task/list/$BOARD_OID" | jq -r --compact-output '.[]? | [.oid, .name, .due, .status.name, [.tags[].name]]')
  remove_square_brackets "$RESPONSE" 
}

#Grab the tasks and save the json to tmp
#https://www.rememberthemilk.com/services/api/methods/rtm.tasks.getList.rtm
tasks_getList_open () {
  get_board_oid
  args="status=0"
  RESPONSE=$(curl -s -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" "$api_url/task/search/$BOARD_OID?$args" | jq -r --compact-output '.[]? | [.oid, .name, .due, .status.name, [.tags[].name]]')
  
  remove_square_brackets "$RESPONSE"
}

remove_square_brackets() {
  echo '.oid, .name, .due, .status.name, .tags[].name' > DATA.txt
  echo "$1" | sed 's/^\[//g' | sed 's/\]$//g' >> DATA.txt
#  echo "${RESPONSE}" | sed 's/^\[//g' | sed 's/\]$//g' >> DATA.txt
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
  while IFS=, read -r oid name due status tags
    do
    # if due is not blank, exclude the header and the due date has passed
#    echo due is $due
#    echo status is $status
#    echo CURRENTUTC is $CURRENTUTC   
#working    if [ "$due" != ".due" -a "$due" \< "$CURRENTUTC" ]; then 
    if [ "$due" \< "$CURRENTUTC" ]; then 
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
    echo "$oid|$name|$due|$each_tag" | sed 's/"//g' >> OVERDUE_ALL.txt
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
  if [ -e "$SCRIPTDIR/.quirecfg" ]; then
    Print_Output "false" "using .quirecfg"
    . $SCRIPTDIR/.quirecfg
  else
    Print_Output "false" "no .quirecfg file exists. run script with authorize parameter"
    PrintLog "no .quirecfg file exists. run script with authorize parameter"
    exit 1
  fi
}
