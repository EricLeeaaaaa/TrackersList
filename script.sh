#!/bin/bash

cache_dir=".cache"
cache_file="$cache_dir/cache.txt"
temp_dir="$cache_dir/temp"
mkdir -p "$temp_dir"

# 函数：验证 tracker
verify_tracker() {
    local tracker=$1
    local protocol=$(echo $tracker | cut -d: -f1)
    local domain=$(echo $tracker | cut -d/ -f3 | cut -d: -f1)
    local timeout=2

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

export -f verify_tracker

# 处理其他仓库
for folder in $(find $cache_dir -type d -maxdepth 1 ! -name $cache_dir ! -name "Trackers" ! -name "temp");
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
cat $cache_file | sort -u | parallel --timeout 300 --joblog $temp_dir/parallel.log verify_tracker | tee $temp_dir/verified_trackers.txt

# 分类 trackers
cat $temp_dir/verified_trackers.txt | sort -u > all.txt
grep "^http:" $temp_dir/verified_trackers.txt | sort -u > http.txt
grep "^https:" $temp_dir/verified_trackers.txt | sort -u > https.txt
grep "^udp:" $temp_dir/verified_trackers.txt | sort -u > udp.txt
grep "^ws" $temp_dir/verified_trackers.txt | sort -u > ws.txt

# 清理缓存文件
rm -rf $cache_file $temp_dir
