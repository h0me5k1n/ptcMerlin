# ptcMerlin
Apply internet connection blocking on Asus Merlin based on third party app task completion - tested with the following providers:

https://www.rememberthemilk.com/

https://quire.io/

# Summary
First, authorisation is done to store keys required to interact with the api for the task application. Once this is in place, cru can be used to automatically check for overdue tasks.

Tasks in the online task management tool (quire/rtm) need to be "tagged" with an identifier and a "tag2mac" lookup file is used to determine which tags relate to specific mac addresses.

The final step of the configuration uses the "Web Apps & Filters" capability in the Asus Router "Parental Controls" to apply blocking - if the script finds a mac address associated with a tag that has overdue task/s, the filtering will be enabled. This allows the parental controls filtering to be applied when tasks are overdue BUT WILL DISABLE FILTERING FOR MAC ADDRESSES WHEN THERE ARE NO OVERDUE TASKS! IF YOU ALREADY USE THIS CAPABILITY TO RESTRICT TRAFFIC BY MAC ADDRESSES, THIS SCRIPT WILL DISABLE IT FOR ANY MAC ADDRESSES IN THE LOOKUP FILE WHILSTTHERE ARE NO OVERDUE TASKS.

Personally, I use this to disable streaming, online gaming and instant messaging until the dishwasher is emptied!

# Installation
1. Clone the repo
2. Get api keys from the provider
3. Update the cfg file with the api key detail
4. Update the tag2mac_lookup file with details of which tags relate to specific mac addresses - see the sample file for the format
3. run the following and then follow the steps on screen **ptcmerlin.sh [provider] authorise**
4. (optional) run **ptcmerlin.sh [provider] checktoken**
5. (optional) run **ptcmerlin.sh [provider] check_overdue**

# Usage
You can manually trigger a check and block/unblock upon overdue tasks with
**ptcmerlin.sh [provider] process_overdue**

You can add a scheduled check every 15 minutes using
**ptcmerlin.sh [provider] cru_add**

You can configure a cru entry to be added at startup using (to automatically configure the 15 minute check above after a restart)
**ptcmerlin.sh [provider] autostart_enabled**

just run **ptcmerlin.sh** on it's own to see the other options

# Detailed Information
* I used rtm solidly for a 3 months prior to publishing this repo but quire is relatively untested! The quire integration was written and tested as an alternative but never fully used to manage tasks and blocking in live task assignment and tracking.
* See the documentation for the rtm and quire to find out how to get api keys - they need to be requested.
* You can only use one third party task management system at a time! If you try using more than one, tasks could be overdue in one but not in the other, causing unexpected blocking or unblocking results
* keep your cfg files safe! They contain api credentials! 
