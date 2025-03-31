# App log contains name of applications Date/Time and memory usage
# based on meory usage list all that use more than 1500mb, print it out
# as a list that contains name of the application and memory usage +MB

# Samlpe input
# APP_NAME	DATETIME	MEMORY_USAGE(MB)
# app-E47F1B2C	2025-03-27 15:32	1243
# app-0A9D3F67	2025-03-27 09:47	2823
# app-B628E9CD	2025-03-27 11:15	183
# app-C91F02AB	2025-03-27 16:09	299
# app-D37BA904	2025-03-27 14:05	2554
# app-EF0486A1	2025-03-27 20:42	1087
# app-75BC1DF0	2025-03-27 07:53	578
# app-F14AB780	2025-03-27 12:24	2713
# app-A94D28F3	2025-03-27 18:07	132
# app-C4B7098F	2025-03-27 13:38	2235

# Sample output
# app-718F4E2A 2900MB
# app-0A9D3F67 2823MB
# app-F14AB780 2713MB
# app-D37BA904 2554MB
# app-4BA302F9 2478MB
# app-C4B7098F 2235MB
# app-0359F720 2005MB
# app-0CFD18AB 1758MB


#!/bin/bash

sort -k4 -nr applog.log > tmp.log
while read -r line
do
  if [ "$(echo "$line" | awk '{print $4}')" -gt 1500 ]; then
    line="$(echo "$line" | awk '{print $1 , $4}')MB"
    log+=("$line")
  fi
done < tmp.log

rm -f tmp.log
#printf '%s\n' "${log[@]}"

echo "${log[1]}"
echo $(awk '{print $4}' <<< $log[1])
