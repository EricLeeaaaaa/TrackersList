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

# 检查 tracker 可用性
verify_tracker() {
    local tracker=$1
    local protocol=$(echo "$tracker" | cut -d: -f1)
    local host=$(echo "$tracker" | cut -d/ -f3 | cut -d: -f1)

    # 使用 Google 的 DNS 服务器，超时设置为 2 秒
    if ! host -W 2 "$host" 8.8.8.8 > /dev/null 2>&1; then
        return 1
    fi

    case $protocol in
        http|https)
            if curl -sS --connect-timeout 2 --max-time 3 -o /dev/null "$tracker"; then
                echo "$tracker"
            fi
            ;;
        udp)
            if nc -zu -w2 "$host" $(echo "$tracker" | cut -d: -f3 | cut -d/ -f1) 2>/dev/null; then
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

# 并行验证 trackers，设置总超时为 5 分钟，使用 timeout 命令限制每个作业的运行时间
cat all.txt | parallel --timeout 300 --joblog parallel.log --jobs 50 'timeout 5s bash -c "verify_tracker {}"' > all.txt


# 提取 HTTPS trackers
grep '^https://' all.txt > https.txt

# 显示统计信息
echo "处理前 tracker 数量: $(wc -l < merged.txt)"
echo "验证后 tracker 数量: $(wc -l < all.txt)"
echo "HTTPS tracker 数量: $(wc -l < https.txt)"
