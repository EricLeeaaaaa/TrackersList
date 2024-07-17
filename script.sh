#!/bin/bash

# 源列表
sources=(
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
    "https://raw.githubusercontent.com/hezhijie0327/Trackerslist/main/trackerslist_combine.txt"
    "https://raw.githubusercontent.com/Azathothas/Trackers/main/trackers_all.txt"
    "https://newtrackon.com/api/all"
)

# 下载并合并所有源
curl -sS "${sources[@]}" | grep -E '^(http|udp|ws)' | sort -u > combined.txt

# 验证并分类 trackers
verify_tracker() {
    local tracker=$1
    local protocol=$(echo "$tracker" | cut -d: -f1)

    case $protocol in
        http|https)
            if curl -sS --connect-timeout 3 -o /dev/null "$tracker"; then
                echo "$tracker"
                [[ $tracker == https://* ]] && echo "$tracker" >> https.txt
            fi
            ;;
        udp)
            if nc -zu -w3 $(echo "$tracker" | cut -d/ -f3 | cut -d: -f1) $(echo "$tracker" | cut -d: -f3 | cut -d/ -f1) 2>/dev/null; then
                echo "$tracker"
            fi
            ;;
        ws|wss)
            # 对于 WebSocket，我们暂时不验证，直接添加
            echo "$tracker"
            ;;
    esac
}

export -f verify_tracker

# 并行验证 trackers
cat combined.txt | parallel --timeout 300 --jobs 50 verify_tracker > all.txt

# 清理并排序结果
sort -u all.txt -o all.txt
sort -u https.txt -o https.txt

# 删除临时文件
rm combined.txt
