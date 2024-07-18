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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

download_and_verify_tracker() {
    local url=$1

    curl -sS "$url" | grep -E '^(http|udp|ws)' | sort -u | while read -r tracker; do
        verify_tracker "$tracker"
    done
}

normalize_tracker_url() {
    local tracker=$1
    tracker=${tracker#*://}
    tracker=${tracker//:80\//}
    tracker=${tracker//:443\//}
    tracker=${tracker%/announce}
    tracker=${tracker%/announce.php}
    tracker=${tracker%/}
    echo "$tracker"
}

verify_tracker() {
    local tracker=$1
    local protocol=${tracker%%:*}
    local host=${tracker#*//}
    host=${host%%/*}
    host=${host%%:*}
    local normalized_tracker=$(normalize_tracker_url "$tracker")

    if ! host -W 3 "$host" $DNS_SERVER > /dev/null 2>&1; then
        return 1
    fi

    local is_valid=false
    case $protocol in
        http|https)
            if curl -sS -I --connect-timeout 5 --max-time 10 "$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ [23]"; then
                is_valid=true
            fi
            ;;
        udp)
            local port=${tracker##*:}
            port=${port%%/*}
            if (echo -en "\x00\x00\x04\x17\x27\x10\x19\x80" | nc -u -w5 "$host" "$port" | grep -q "^..................."); then
                is_valid=true
            fi
            ;;
        ws|wss)
            if curl -sS -I --connect-timeout 5 --max-time 10 -H "Upgrade: websocket" -H "Connection: Upgrade" "$tracker" 2>&1 | grep -qE "^HTTP/[0-9.]+ 101"; then
                is_valid=true
            fi
            ;;
    esac

    if [ "$is_valid" = true ]; then
        echo "$protocol://$normalized_tracker" >> "$TMP_DIR/all_temp.txt"
        [[ $protocol == "http" ]] && echo "$protocol://$normalized_tracker" >> "$TMP_DIR/http_temp.txt"
    fi
}

verify_all_trackers() {
    echo "正在验证 trackers..."
    parallel --timeout $((TIMEOUT * 60)) --joblog parallel.log --jobs $PARALLEL_JOBS \
        download_and_verify_tracker ::: "${TRACKER_SOURCES[@]}"
}

remove_duplicate_trackers() {
    echo "正在移除重复的 trackers..."
    awk -F'://' '!seen[$2]++' "$TMP_DIR/all_temp.txt" | sort -u > "$ALL_TRACKERS_FILE"
    awk -F'://' '!seen[$2]++' "$TMP_DIR/http_temp.txt" | sort -u > "$HTTP_TRACKERS_FILE"
}

show_tracker_stats() {
    echo "验证通过的 trackers 总数: $(wc -l < "$ALL_TRACKERS_FILE")"
    echo "验证通过的 HTTP trackers 数: $(wc -l < "$HTTP_TRACKERS_FILE")"
}

main() {
    verify_all_trackers
    remove_duplicate_trackers
    show_tracker_stats
}

main
