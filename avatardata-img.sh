#!/bin/sh

timestamp=$(date "+%s")
currentDir=$(cd `dirname $0`;pwd)
mkdir apis.avatardata.img
#阿凡达笑话趣图类型
for ((id=1;id<=300;++id))
do
	echo "id --> $id"
    curl "http://api.avatardata.cn/Joke/QueryImgByTime?key=e03a050da0cd40ddb51fc715ebb94e31&page=$id&rows=50&sort=desc&time=$timestamp" > $currentDir/apis.avatardata.img/joke-img-content$id.txt
done

sh $currentDir/joke-task.sh -d $currentDir/apis.avatardata.img -c $currentDir/avatardata-img.conf 
