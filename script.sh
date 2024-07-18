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

# 合并所有源
curl -sS "${sources[@]}" | grep -E '^(http|udp|ws)' | sort -u > temp.txt

# 去重
awk '
BEGIN { FS = "[:/?]" }
{
    proto = $1
    domain = $4
    path = $5 ? "/" $5 : ""
    for (i = 6; i <= NF; i++) path = path "/" $i
    if (path == "") path = "/"
    key = proto "://" domain path
    if (!(key in seen)) {
        seen[key] = 1
        print $0
    }
}
' temp.txt | sort > all.txt

# 提取 HTTPS trackers
grep '^https://' all.txt > https.txt

# 显示统计信息
echo "总 tracker 数量: $(wc -l < all.txt)"
echo "HTTPS tracker 数量: $(wc -l < https.txt)"

# 清理临时文件
rm temp.txt
