#!/bin/bash

# 配置参数
TIMEOUT=10                # 单个 tracker 验证的超时时间（秒）
PARALLEL_JOBS=50          # 并行验证的作业数
DNS_SERVER="114.114.114.114"  # 用于 DNS 查询的服务器
ALL_TRACKERS_FILE="all.txt"   # 所有验证通过的 trackers 输出文件
HTTP_TRACKERS_FILE="http.txt" # 仅 HTTP trackers 输出文件

# Tracker 源列表
TRACKER_SOURCES=(
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
    "https://raw.githubusercontent.com/hezhijie0327/Trackerslist/main/trackerslist_combine.txt"
    "https://raw.githubusercontent.com/Azathothas/Trackers/main/trackers_all.txt"
    "https://newtrackon.com/api/all"
)

# 下载并合并所有 tracker 列表
download_and_merge_trackers() {
    echo "正在下载并合并 tracker 列表..."
    curl -sS "${TRACKER_SOURCES[@]}" | grep -E '^(http|udp|ws)' | sort -u > combined_trackers.txt
}

# 标准化 tracker URL
normalize_tracker_url() {
    local tracker=$1
    # 移除协议
    tracker=${tracker#*://}
    # 移除默认端口 (:80 for http, :443 for https)
    tracker=${tracker//:80\//\/}
    tracker=${tracker//:443\//\/}
    # 移除结尾的 /announce 或 /announce.php
    tracker=${tracker%/announce}
    tracker=${tracker%/announce.php}
    # 移除结尾的斜杠
    tracker=${tracker%/}
    echo "$tracker"
}

# 验证单个 tracker
verify_tracker() {
    local tracker=$1
    local protocol=${tracker%%:*}
    local host=${tracker#*//}
    host=${host%%/*}
    host=${host%%:*}
    local normalized_tracker=$(normalize_tracker_url "$tracker")

    # DNS 检查
    if ! host -W 3 "$host" $DNS_SERVER > /dev/null 2>&1; then
        return 1
    fi

    local is_valid=false
    case $protocol in
        http|https)
            # 检查 HTTP(S) tracker
            if curl -sS -I --connect-timeout 5 --max-time 10 "$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ [23]"; then
                is_valid=true
            fi
            ;;
        udp)
            # 检查 UDP tracker
            local port=${tracker##*:}
            port=${port%%/*}
            if (echo -en "\x00\x00\x04\x17\x27\x10\x19\x80" | nc -u -w5 "$host" "$port" | grep -q "^..................."); then
                is_valid=true
            fi
            ;;
        ws|wss)
            # 检查 WebSocket tracker
            if curl -sS -I --connect-timeout 5 --max-time 10 -H "Upgrade: websocket" -H "Connection: Upgrade" "$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ 101"; then
                is_valid=true
            fi
            ;;
    esac

    if [ "$is_valid" = true ]; then
        echo "$protocol://$normalized_tracker"
        [[ $protocol == "http" ]] && echo "$protocol://$normalized_tracker" >> "$HTTP_TRACKERS_FILE"
    fi
}

# 验证所有 trackers
verify_all_trackers() {
    echo "正在验证 trackers..."
    export -f verify_tracker normalize_tracker_url
    export HTTP_TRACKERS_FILE
    parallel --timeout $((TIMEOUT * 60)) --joblog parallel.log --jobs $PARALLEL_JOBS \
        "timeout ${TIMEOUT}s bash -c 'verify_tracker {}'" < combined_trackers.txt > "$ALL_TRACKERS_FILE"
}

# 移除重复的 trackers
remove_duplicate_trackers() {
    echo "正在移除重复的 trackers..."
    # 使用 awk 去重，保留协议信息
    awk -F'://' '!seen[$2]++' "$ALL_TRACKERS_FILE" | sort -u > temp_all_trackers.txt
    mv temp_all_trackers.txt "$ALL_TRACKERS_FILE"

    awk -F'://' '!seen[$2]++' "$HTTP_TRACKERS_FILE" | sort -u > temp_http_trackers.txt
    mv temp_http_trackers.txt "$HTTP_TRACKERS_FILE"
}

# 清理临时文件
cleanup_temp_files() {
    echo "正在清理临时文件..."
    rm combined_trackers.txt
}

# 显示 tracker 统计信息
show_tracker_stats() {
    echo "验证通过的 trackers 总数: $(wc -l < "$ALL_TRACKERS_FILE")"
    echo "验证通过的 HTTP trackers 数: $(wc -l < "$HTTP_TRACKERS_FILE")"
}

# 主函数
main() {
    download_and_merge_trackers
    verify_all_trackers
    remove_duplicate_trackers
    cleanup_temp_files
    show_tracker_stats
}

# 执行主函数
main
