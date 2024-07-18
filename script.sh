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
curl -sS "${sources[@]}" | grep -E '^(http|udp|ws)' > temp.txt

# 高级去重
awk '
BEGIN { FS = "[:/?]" }
{
    proto = $1
    domain = $4
    port = $5
    path = ""
    for (i = 6; i <= NF; i++) path = path "/" $i
    if (path == "") path = "/"
    
    # 标准化端口
    if ((proto == "http" && port == "80") || (proto == "https" && port == "443")) {
        port = ""
    }
    
    # 构建键，忽略默认端口
    key = proto "://" domain (port ? ":" port : "") path
    
    # 如果这个键是新的，或者比之前存储的URL更短，就更新它
    if (!(key in seen) || length($0) < length(seen[key])) {
        seen[key] = $0
    }
}
END {
    for (key in seen) {
        print seen[key]
    }
}
' temp.txt | sort -u > all.txt

# 提取 HTTPS trackers
grep '^https://' all.txt > https.txt

# 显示统计信息
echo "总 tracker 数量: $(wc -l < all.txt)"
echo "HTTPS tracker 数量: $(wc -l < https.txt)"

# 清理临时文件
rm temp.txt
