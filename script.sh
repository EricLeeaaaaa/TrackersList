#!/bin/bash

cache_dir=".cache"
cache_file="$cache_dir/cache.txt"

# 函数：验证 tracker
verify_tracker() {
    local tracker=$1
    local protocol=$(echo $tracker | cut -d: -f1)
    local domain=$(echo $tracker | cut -d/ -f3 | cut -d: -f1)
    local timeout=5

    case $protocol in
        http|https)
            if curl -s --connect-timeout $timeout -o /dev/null -w "%{http_code}" "$tracker" | grep -q "2[0-9][0-9]\|3[0-9][0-9]"; then
                echo $tracker
            fi
            ;;
        udp)
            if nc -zu -w $timeout $domain 6969 > /dev/null 2>&1; then
                echo $tracker
            fi
            ;;
        ws|wss)
            if curl -s --connect-timeout $timeout -o /dev/null "$tracker"; then
                echo $tracker
            fi
            ;;
    esac
}

# 处理其他仓库
for folder in $(find $cache_dir -type d -maxdepth 1 ! -name $cache_dir ! -name "Trackers");
do
    for file in $(
        ls -tr $folder/*.txt |
        grep -i -v aria |
        grep -i -v blacklist);
    do
        (
        awk NF $file | sort | uniq |
        sed '/#/d' |
        grep -i -E ^"http|udp|ws";
        echo)  >> $cache_file
    done
done

# 专门处理 Azathothas/Trackers 仓库
trackers_folder="$cache_dir/Trackers"
if [ -d "$trackers_folder" ]; then
    for file in $trackers_folder/trackers_*.txt; do
        (
        awk NF $file | sort | uniq |
        sed '/#/d' |
        grep -i -E ^"http|udp|ws";
        echo)  >> $cache_file
    done
fi

# 验证和分类 trackers
echo "Verifying trackers..."
cat $cache_file | sort -u | while read tracker; do
    verified_tracker=$(verify_tracker "$tracker")
    if [ ! -z "$verified_tracker" ]; then
        echo $verified_tracker >> all.txt
        case $verified_tracker in
            http:*) echo $verified_tracker >> http.txt ;;
            https:*) echo $verified_tracker >> https.txt ;;
            udp:*) echo $verified_tracker >> udp.txt ;;
            ws:*|wss:*) echo $verified_tracker >> ws.txt ;;
        esac
    fi
done

# 最终处理
for file in all.txt https.txt http.txt udp.txt ws.txt; do
    if [ -f "$file" ]; then
        sort -u $file -o $file
    else
        touch $file
    fi
done

# 清理缓存文件
rm -f $cache_file
