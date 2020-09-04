#!/bin/bash

homeDir=$(pwd)"/"
name="old"
dbIp="<数据库连接IP>"
dbPort="<数据库连接Port>"
dbAccount="<数据库连接账户>"
dbPassword="<数据库连接账户密码>"
dbName="<数据库名称>"

# get database schema
function getSchema(){
	echo "now get database schema from $dbIp:$dbPort..."

	# c.ORDINAL_POSITION
	# 获取列
	local cmd2=`mysql -h"$dbIp" -P"$dbPort" -u"$dbAccount" -p"$dbPassword" -e "
		use $dbName;
		SELECT c.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE, c.IS_NULLABLE, c.EXTRA FROM information_schema.COLUMNS c WHERE c.TABLE_SCHEMA = '$dbName';
	" | grep -v "TABLE_NAME" > "$name"Columns.csv`

	# 获取表名
	local cmd3="mysql -h$dbIp -P$dbPort -u$dbAccount -p$dbPassword -e \"use $dbName; SHOW TABLES; \" | grep -v \"Tables_in_$dbName\" > $name""TableNames.csv"
	eval $cmd3

	# 获取索引
	mysql -h$dbIp -P$dbPort -u$dbAccount -p$dbPassword -e "SELECT TABLE_NAME, NON_UNIQUE, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME,   INDEX_TYPE FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = '$dbName' ORDER BY TABLE_NAME,NON_UNIQUE,INDEX_NAME,SEQ_IN_INDEX;" | grep -v "TABLE_NAME" > $name"Indexs.csv"

	echo "get database schema success！"
}

# 调用方法
getSchema