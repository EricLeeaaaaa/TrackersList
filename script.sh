#!/bin/bash

cache_dir=".cache"
cache_file="$cache_dir/cache.txt"

# 函数：验证 tracker
verify_tracker() {
    local tracker=$1
    local protocol=$(echo $tracker | cut -d: -f1)
    local domain=$(echo $tracker | cut -d/ -f3 | cut -d: -f1)
    local port=$(echo $tracker | cut -d: -f3 | cut -d/ -f1)

    # 默认端口
    if [[ -z "$port" ]]; then
        case $protocol in
            http) port=80 ;;
            https) port=443 ;;
            udp) port=6969 ;;
            ws|wss) port=443 ;;
        esac
    fi

    # 使用 nmap 验证
    if nmap -p $port $domain | grep -q "open"; then
        echo $tracker
    fi
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
