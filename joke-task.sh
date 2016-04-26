#!/bin/sh

function usage(){
	echo "this script is to handle the joke data source
the option is:
	-d	you must point the data source folder which include the data source,and this folder should not contain other files besides data source file
	-c	you must point a config file with json form,and there must be these keys : mysql,field,field_type and is_string
	-l	you can add this option to create an log which to save sql
	-s	slient mode
about the config file:
	mysql --> it contain the mysql connection information,its's value is a json string which must contain : 
		mysql_host 	--> mysql host address
		mysql_user 	--> mysql username
		mysql_db   	--> mysql database name
		mysql_tbl  	--> mysql table name
		mysql_engine 	--> mysql storage engine
		mysql_charset	--> mysql character set(if use chinese,you must point utf8)
		mysql_fix	--> the addtional option for connect mysql host
	field --> its's value is an array which contain fields of mysql_tbl and you must be sure that the data source include these keys
	field_type --> its's value is to descript the data type of fields,a json string
	is_string --> it is important to descript which field is string.usually,they are all string type besides number"
}

LOGDIR=$(pwd)"/logs"
DATE_PARTITION=$(date "+%Y%m%d")
HOUR_PARTITION=$(date "+%H%M%S")
LOG=$LOGDIR"/"$DATE_PARTITION"/"$HOUR_PARTITION".log"
SQL=$LOGDIR"/"$DATE_PARTITION"/"$HOUR_PARTITION".sql"


silent=0

function ECHO(){
	if [ "$silent" -eq "0" ]
	then
		echo $1 | tee -a $LOG
	else
		echo $1 >> $LOG
	fi
}

while [ -n "$1" ]
do
	case $1 in
	-s)
	silent=1
	;;
	-d) 
	DIR=$(cd `dirname $2`;pwd)"/"$(basename $2)
	if [ -d "$DIR" ]
	then
		echo "data source : $DIR"
		if [ -r "$DIR" ]
		then
			echo "$DIR is readable"
		else
			echo "error : $DIR is unreadable"
			exit 1
		fi
	else
		echo "error : data source $DIR is not an effective folder"
		exit 1
	fi
	shift
	;;
	-c) 
	CONFIG=$(cat $2)
	if [ "$?" -ne 0 ]
	then
		echo "error : $2 is not an effctive config file"
		exit
	fi
	shift
	;;
	-h) 
	usage
	exit 0
	;;
	*) echo "warning : invalid option $1";;
	esac
	shift
done


`mkdir -p "$LOGDIR/$DATE_PARTITION"`
`touch "$LOG"`
`touch "$SQL"`
#DIR=$1
#CONFIG=$(cat $2)
#if [ $? -ne 0 ]
#then
#	echo "the config is not correct"
#	exit 1
#fi
#conf content
#mysql_host=xxx
#mysql_user=xxx
#mysql_pass=xxx
#mysql_fix =xxx
#mysql_tbl =xxx
#filed=xxx

ECHO "$CONFIG"

function delQuote(){
	res=$(echo $1 | sed 's/\"//g')
	echo $res
}

function changeSpace(){
	res=$(echo $1 | sed 's/ /<%space%>/g')
	echo $res
}

function restoreSpace(){
	res=$(echo $1 | sed 's/<%space%>/ /g')
	echo $res
}

mysql=$(echo $CONFIG | jq ".mysql")
field=$(echo $CONFIG | jq ".field")
field_type=$(echo $CONFIG | jq ".field_type")
is_string=$(echo $CONFIG | jq ".is_string")
result=$(delQuote $(echo $CONFIG | jq ".result"))

success_condition=$(echo $CONFIG | jq ".success_filter.value")
success_key=$(echo $CONFIG | jq ".success_filter.name")


mysql_host=$(delQuote $(echo $mysql | jq ".mysql_host"))
mysql_pass=$(delQuote $(echo $mysql | jq ".mysql_pass"))
mysql_user=$(delQuote $(echo $mysql | jq ".mysql_user"))
mysql_tbl=$(delQuote $( echo $mysql | jq ".mysql_tbl"))
mysql_fix=$(delQuote $( echo $mysql | jq ".mysql_fix"))
mysql_db=$(delQuote $(  echo $mysql | jq ".mysql_db"))
mysql_engine=$(delQuote $(echo $mysql | jq ".mysql_engine"))
mysql_charset=$(delQuote $(echo $mysql | jq ".mysql_charset"))

ECHO "result --> $result"
ECHO "mysql --> $mysql"
ECHO "field --> $field"
ECHO "field_type --> $field_type"
ECHO "is_string --> $is_string"
ECHO "mysql_host --> $mysql_host"
ECHO "mysql_pass --> $mysql_pass"
ECHO "mysql_user --> $mysql_user"
ECHO "mysql_tbl --> $mysql_tbl"
ECHO "mysql_fix --> $mysql_fix"
ECHO "mysql_db --> $mysql_db"
ECHO "mysql_engine --> $mysql_engine"
ECHO "mysql_charset --> $mysql_charset"
schemas=""
index=0

create_info="id int(11) unsigned primary key auto_increment"
while [ true ]
do
	new_schema=$(delQuote $(echo $field | jq ".[$index]"))
	if [ $new_schema = "null" ]
	then
		break
	fi
	echo $new_schema
	schemas=$schemas" "$new_schema
	index=$[ $index + 1 ]
done

ECHO "schemas --> $schemas"

for schema in $schemas
do
	schema_type=$(delQuote $(echo $field_type | jq ".$schema"))
	create_info=$create_info","$schema" "$schema_type
done

function createInsertQuery(){
	value_schemas=$(echo $schemas | sed 's/[ ]\{1,\}/,/g')
	value=""
	for schema in $schemas
	do
		cur_value=$(restoreSpace "$1")
		shift
		string_or_not=$(echo $is_string | jq ".$schema")
		if [ $string_or_not -eq 1 ]
		then
			value=$value" "$cur_value
		else
			value=$value" "$(delQuote $cur_value)
		fi
		if [ "$1" != "" ]
		then
			value=$value","
		fi
	done
	echo "insert into $mysql_tbl($value_schemas) values($value);"
}

mysql_query="create database if not exists $mysql_db character set $mysql_charset;
use $mysql_db;
create table if not exists $mysql_tbl($create_info)engine=$mysql_engine default charset=$mysql_charset;"
echo $mysql_query >> $SQL
source_files=$(ls $DIR)
#echo $source_files
for file in $source_files
do
	file=$DIR"/$file"
	success_value=$(cat $file | jq ".$success_key")
	if [ "$success_condition" != "$success_value" ]
	then
		echo "this file has no messages"
		continue
	fi
	echo "file --> $file"
	echo "result --> $result"
	data_source=$(cat $file | jq ".$result")
	echo "data_source --> $data_source"
	if [ "$data_source" = "null" ]
	then
		ECHO "warning : $file is unuseful"
		continue
	fi
	
	index=0
	while [ true ]
	do
		res=$(echo $data_source | jq ".[$index]")
	#	echo "res ===>>> "$res
		if [ "$res" = "null" ]
		then
			break;
		fi
		value=""
		for schema in $schemas
		do
#			new_value=$(delQuote $(echo $res | jq ."$schema"))
			new_value=$(changeSpace "$(echo $res | jq ".$schema")")
			ECHO "$schema-->$new_value"
			value=$value" "$new_value
		done
		insert_query=$(createInsertQuery $value)
#		mysql_query="$mysql_query
#$insert_query;"
		echo $insert_query >> $SQL
		index=$[ $index + 1 ]
	done
done
#echo $mysql_query > $SQL
`mysql -u$mysql_user -h$mysql_host -p$mysql_pass $mysql_fix -s -e "source $SQL"`
if [ "$?" != "0" ]
then
	ECHO "warning : mysql execute sql had some question"
fi

TAR_GZ="$LOGDIR/$DATE_PARTITION"$(basename $DIR)"_$HOUR_PARTITION".tar.gz
`tar -zcvf $TAR_GZ $DIR/*`

if [ "$?" != "0" ]
then
	ECHO "warning : tar execute had some question"
fi

`rm -rf $DIR`
`mail -s "this email came from sprite spider --no reply" ns_xlz@foxmail.com wuyongjing3352@163.com < $LOG`
