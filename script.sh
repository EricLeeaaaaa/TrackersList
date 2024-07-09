#!/bin/bash

cache_dir=".cache"
cache_file="$cache_dir/cache.txt"

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
        grep -i -E ^"http|udp";
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
        grep -i -E ^"http|udp";
        echo)  >> $cache_file
    done
fi

# 最终处理
awk NF $cache_file | sort | uniq > all.txt

# 创建仅包含 HTTPS 链接的文件
grep -i ^"https" all.txt | sort | uniq > https.txt
