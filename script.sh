#!/bin/bash

# 源列表
sources=(
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
    "https://raw.githubusercontent.com/hezhijie0327/Trackerslist/main/trackerslist_tracker.txt"
    "https://raw.githubusercontent.com/Azathothas/Trackers/main/trackers_all.txt"
)

# 下载并合并所有源
curl -sS "${sources[@]}" | grep -E '^(http|udp|ws)' | sort -u > combined.txt

# 验证并分类 trackers
verify_tracker() {
    local tracker=$1
    if curl -sS --connect-timeout 3 -o /dev/null "$tracker"; then
        echo "$tracker"
        [[ $tracker == https://* ]] && echo "$tracker" >> https.txt
    fi
}

export -f verify_tracker

# 并行验证 trackers
cat combined.txt | parallel --timeout 300 --jobs 50 verify_tracker > all.txt

# 清理并排序结果
sort -u all.txt -o all.txt
sort -u https.txt -o https.txt

# 删除临时文件
rm combined.txt
