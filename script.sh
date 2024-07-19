#!/bin/bash

# 源列表
sources=(
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
    "https://raw.githubusercontent.com/hezhijie0327/Trackerslist/main/trackerslist_combine.txt"
    "https://raw.githubusercontent.com/Azathothas/Trackers/main/trackers_all.txt"
    "https://newtrackon.com/api/all"
    #https://raw.githubusercontent.com/EricLeeaaaaa/TrackersList/main/demo_tracker.txt
)

# 仅合并文件
curl -sS "${sources[@]}" | grep -E '^(http|udp|ws)' > merged.txt

# 合并并去重
curl -sS "${sources[@]}" | 
    tr -s '[:space:]' '\n' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
    sed -E 's#(https?://|udp://|wss?://)#\n\1#g' |
    sed -E 's#^(https?://[^/]+):(80|443)/#\1/#' |
    sed -E 's#^([^:]+://[^/]+)(:\d+)?/announce.*#\1\2/announce#' |
    grep -E '^(http|udp|ws).*://[^/]+/announce$' |
    sort -u > all.txt

# 提取 HTTPS trackers
grep '^https://' all.txt > https.txt

# 显示统计信息
echo "处理前 tracker 数量: $(wc -l < merged.txt)"
echo "处理后 tracker 数量: $(wc -l < all.txt)"
echo "HTTPS tracker 数量: $(wc -l < https.txt)"
