#!/bin/sh

timestamp=$(date "+%s")
mkdir apis.avatardata.txt
#阿凡达笑话趣图类型
for ((id=1;id<=700;++id))
do
	echo "id --> $id"
    curl "http://api.avatardata.cn/Joke/QueryJokeByTime?key=e03a050da0cd40ddb51fc715ebb94e31&page=$id&rows=50&sort=desc&time=$timestamp" > apis.avatardata.txt/joke-txt-content$id.txt
done

sh joke-task.sh -d apis.avatardata.txt -c avatardata-txt.conf 
