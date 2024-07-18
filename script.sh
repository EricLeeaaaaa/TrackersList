#!/bin/bash

# 配置参数
TIMEOUT=10
PARALLEL_JOBS=50
DNS_SERVER="114.114.114.114"
ALL_TRACKERS_FILE="all.txt"
HTTP_TRACKERS_FILE="http.txt"

# Tracker 源列表
TRACKER_SOURCES=(
    "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    "https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all.txt"
    "https://raw.githubusercontent.com/DeSireFire/animeTrackerList/master/AT_all.txt"
    "https://raw.githubusercontent.com/hezhijie0327/Trackerslist/main/trackerslist_combine.txt"
    "https://raw.githubusercontent.com/Azathothas/Trackers/main/trackers_all.txt"
    "https://newtrackon.com/api/all"
)

download_and_merge_trackers() {
    echo "正在下载并合并 tracker 列表..."
    curl -sS "${TRACKER_SOURCES[@]}" | grep -E '^(http|udp|ws)' | sort -u > combined_trackers.txt
}

# 创建一个单独的验证脚本
cat > verify_tracker.sh <<EOL
#!/bin/bash

normalize_tracker_url() {
    local tracker=\$1
    tracker=\${tracker#*://}
    tracker=\${tracker//:80\//\/}
    tracker=\${tracker//:443\//\/}
    tracker=\${tracker%/announce}
    tracker=\${tracker%/announce.php}
    tracker=\${tracker%/}
    echo "\$tracker"
}

verify_tracker() {
    local tracker=\$1
    local protocol=\${tracker%%:*}
    local host=\${tracker#*//}
    host=\${host%%/*}
    host=\${host%%:*}
    local normalized_tracker=\$(normalize_tracker_url "\$tracker")

    if ! host -W 3 "\$host" $DNS_SERVER > /dev/null 2>&1; then
        return 1
    fi

    local is_valid=false
    case \$protocol in
        http|https)
            if curl -sS -I --connect-timeout 5 --max-time 10 "\$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ [23]"; then
                is_valid=true
            fi
            ;;
        udp)
            local port=\${tracker##*:}
            port=\${port%%/*}
            if (echo -en "\x00\x00\x04\x17\x27\x10\x19\x80" | nc -u -w5 "\$host" "\$port" | grep -q "^..................."); then
                is_valid=true
            fi
            ;;
        ws|wss)
            if curl -sS -I --connect-timeout 5 --max-time 10 -H "Upgrade: websocket" -H "Connection: Upgrade" "\$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ 101"; then
                is_valid=true
            fi
            ;;
    esac

    if [ "\$is_valid" = true ]; then
        echo "\$protocol://\$normalized_tracker"
        [[ \$protocol == "http" ]] && echo "\$protocol://\$normalized_tracker" >> "$HTTP_TRACKERS_FILE"
    fi
}

verify_tracker "\$1"
EOL

chmod +x verify_tracker.sh

verify_all_trackers() {
    echo "正在验证 trackers..."
    parallel --timeout $((TIMEOUT * 60)) --joblog parallel.log --jobs $PARALLEL_JOBS \
        "./verify_tracker.sh {}" < combined_trackers.txt > "$ALL_TRACKERS_FILE"
}

remove_duplicate_trackers() {
    echo "正在移除重复的 trackers..."
    awk -F'://' '!seen[$2]++' "$ALL_TRACKERS_FILE" | sort -u > temp_all_trackers.txt
    mv temp_all_trackers.txt "$ALL_TRACKERS_FILE"

    awk -F'://' '!seen[$2]++' "$HTTP_TRACKERS_FILE" | sort -u > temp_http_trackers.txt
    mv temp_http_trackers.txt "$HTTP_TRACKERS_FILE"
}

cleanup_temp_files() {
    echo "正在清理临时文件..."
    rm combined_trackers.txt verify_tracker.sh
}

show_tracker_stats() {
    echo "验证通过的 trackers 总数: $(wc -l < "$ALL_TRACKERS_FILE")"
    echo "验证通过的 HTTP trackers 数: $(wc -l < "$HTTP_TRACKERS_FILE")"
}

main() {
    download_and_merge_trackers
    verify_all_trackers
    remove_duplicate_trackers
    cleanup_temp_files
    show_tracker_stats
}

main
