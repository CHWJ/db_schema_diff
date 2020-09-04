#!/bin/bash

homeDir=$(pwd)"/"
tempDir="createTable"
dbIp="<数据库连接IP>"
dbPort="<数据库连接Port>"
dbAccount="<数据库连接账户>"
dbPassword="<数据库连接账户密码>"
dbName="<数据库名称>"
tableName=$1

# get database schema
function getSchema(){
	# 目录不存在
	if [ ! -d "$tempDir" ]; then
		mkdir -p -m 755 ${tempDir}
	fi

	local cmd1="mysql -h$dbIp -P$dbPort -u$dbAccount -p$dbPassword -e \"use $dbName;SHOW CREATE TABLE $tableName \\G;\" | sed -e 's/\`//g' > $homeDir$tempDir/$tableName.sql"
	# eval $cmd1
	eval $cmd1
}

# 调用方法
getSchema