#!/bin/bash

homeDir=$(pwd)"/"
oldTableNameFile=$homeDir"oldTableNames.csv"
oldColumnFile=$homeDir"oldColumns.csv"
newTableNameFile=$homeDir"newTableNames.csv"
newColumnFile=$homeDir"newColumns.csv"
createTableDir=$homeDir"createTable"
patchColumnFile=$homeDir"patch_column.sql"
newIndexFile=$homeDir"newIndexs.csv"
oldIndexFile=$homeDir"oldIndexs.csv"
patchIndexFile=$homeDir"patch_index.sql"

echo "" > $patchColumnFile

# 新增表名对应的数组
declare -A addTableDic

function compareTable(){
  local changedTables=[]
  local tempSql=""
  local now=`date '+%Y-%m-%d %H:%M:%S'`
  
  echo " -- Create Table SQL "$now >> $patchColumnFile

  local cmd1="diff $newTableNameFile $oldTableNameFile -y  | grep -E '[|]|[<]' | awk -F'\t' '{print \$1}'"
  for table in $(eval $cmd1)
  do
    addTableDic[$table]=1

    tempSql=`tail -n +3  $createTableDir/$table".sql" | sed 's!Create Table: !!g'`
    echo $tempSql";" >> $patchColumnFile
  done
}

# 拼接 add column，change column
function compareColumnByNewColumn(){
  local tableName=""
  local newColumnName=""
  local newColumnDataType=""
  local newColumnIsNullable=""
  local newColumnLineArr=[]
  local oldColumnLine=""
  # 字段约束条件
  local conditon=""

  local now=`date '+%Y-%m-%d %H:%M:%S'`
  
  echo " -- Alter Table Column SQL "$now >> $patchColumnFile

  # 更改字段分隔符
  IFS=$'\n'
  
  for newColumnLine in $(cat $newColumnFile)
  do
    # TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, EXTRA
    newColumnLineArr=($(echo $newColumnLine | tr "\t" "\n"))
    tableName=${newColumnLineArr[0]}
    newColumnName=${newColumnLineArr[1]}
    newColumnDataType=${newColumnLineArr[2]}
    newColumnIsNullable=${newColumnLineArr[3]}

    if [ "$newColumnIsNullable" = "NO" ]; then
      newColumnIsNullable="NOT NULL"
    else
      newColumnIsNullable="DEFAULT NULL"
    fi

    conditon=$newColumnDataType" "$newColumnIsNullable" "${newColumnLineArr[4]}
        
    if [ -n "$tableName" ] ; then
      # 不是新增的表
      if [ -z "${addTableDic[$tableName]}" ]
      then
        oldColumnLine=`grep -E "^$tableName\s$newColumnName\s" $oldColumnFile`
        if [ -n "$oldColumnLine" ] ; then
          if [ "$oldColumnLine" != "$newColumnLine" ]; then
            printf "ALTER TABLE %s CHANGE COLUMN %s %s %s;\n" $tableName $newColumnName $newColumnName $conditon >> $patchColumnFile
          fi
        else
          printf "ALTER TABLE %s ADD COLUMN %s %s;\n" $tableName $newColumnName $conditon >> $patchColumnFile
        fi
      fi
    fi
  done

  unset newColumnLineArr
}

# 拼接 drop column
function compareColumnByOldColumn(){
  local tableName=""
  local oldColumnName=""
  local oldColumnLineArr=[]
  local oldColumnLine=""
  local newColumnLine=""

  # 更改字段分隔符
  IFS=$'\n'
  
  for oldColumnLine in $(cat $oldColumnFile)
  do
    oldColumnLineArr=($(echo $oldColumnLine | tr "\t" "\n"))
    tableName=${oldColumnLineArr[0]}
    oldColumnName=${oldColumnLineArr[1]}
        
    if [ -n "$tableName" ] ; then
      # 不是新增的表
      if [ -z "${addTableDic[$tableName]}" ]
      then
        newColumnLine=`grep -E "^$tableName\s$oldColumnName\s" $newColumnFile`
        if [ -z "$newColumnLine" ] ; then
          printf "ALTER TABLE %s DROP COLUMN %s;\n" $tableName $oldColumnName >> $patchColumnFile
        fi
      fi
    fi
  done

  unset oldColumnLineArr
}

echo "compare schema..."

compareTable
compareColumnByNewColumn
compareColumnByOldColumn

# 组合索引
function combineAddIndex(){
  local tableName=$1
  local non_unique=$2
  local arr=($(echo $3 | tr " " "\n"))
  local sql=""

  if [ ${#arr[@]} -gt 0 ]; then
    local index_name_arr=()
    local seq_in_index_arr=()
    local column_name_arr=()
    local index_type_arr=()

    # 更改字段分隔符
    IFS=$'\n'

    # INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
    for i in ${!arr[@]}
    do
      local temp_i=$[$i % 4]
      if [ $temp_i -eq 0 ];then
        index_name_arr+=(${arr[$i]})
      fi
      if [ $temp_i -eq 1 ];then
        seq_in_index_arr+=(${arr[$i]})
      fi
      if [ $temp_i -eq 2 ];then
        column_name_arr+=(${arr[$i]})
      fi
      if [ $temp_i -eq 3 ];then
        index_type_arr+=(${arr[$i]})
      fi
    done

    local prev_index_name=""
    local prev_column=""
    local index_name_arr_len=${#index_name_arr[@]}
    local prev_non_unique=""

    # 几个数组的长度相同
    for i in ${!index_name_arr[@]}
    do
      if [ "$prev_index_name" = "${index_name_arr[$i]}" ]; then
        prev_column+=",\`${column_name_arr[$i]}\`"
      else
        if [ $i -gt 0 ]; then
          sql+="ALTER TABLE \`$tableName\` $prev_non_unique USING ${index_type_arr[0]}($prev_column);\n"
        fi

        if [ "$non_unique" = "1" ];then
          prev_non_unique="ADD INDEX \`${index_name_arr[$i]}\`"
        else
          prev_non_unique="ADD PRIMARY KEY"
        fi

        prev_index_name="${index_name_arr[$i]}"
        prev_column="\`${column_name_arr[$i]}\`"
      fi

      if [ $[$index_name_arr_len - 1] -eq $i ]; then
        sql+="ALTER TABLE \`$tableName\` $prev_non_unique USING ${index_type_arr[0]}($prev_column);\n"
      fi
    done

    unset index_name_arr
    unset seq_in_index_arr
    unset column_name_arr
    unset index_type_arr
  fi

  echo "$sql"
}

# 组合索引
function combineDropIndex(){
  local tableName=$1
  local non_unique=$2
  local arr=($(echo $3 | tr " " "\n"))
  local sql=""

  if [ "$non_unique" = "0" ];then
    sql="ALTER TABLE $tableName DROP PRIMARY KEY;\n"
  else
    if [ ${#arr[@]} -gt 0 ]; then
      # 更改字段分隔符
      IFS=$'\n'

      # INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
      for i in ${!arr[@]}
      do
        local temp_i=$[$i % 4]
        if [ $temp_i -eq 0 ];then
          sql+="ALTER TABLE $tableName DROP INDEX ${arr[$i]};\n"
        fi
      done
    fi
  fi

  echo "$sql"
}

# 比较 索引
function compareIndex(){
  declare -A new_index_arr
  local new_index_key=""
  declare -A old_index_arr
  local old_index_key=""
  local lineArr=()
  local alterSql=""

  local now=`date '+%Y-%m-%d %H:%M:%S'`
  echo " -- Alter Table Index SQL "$now > $patchIndexFile

  # 更改字段分隔符
  IFS=$'\n'
  
  # TABLE_NAME, NON_UNIQUE, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
  for line in $(cat $newIndexFile)
  do
    lineArr=($(echo $line | tr "\t" "\n"))    
    # 表名_索引类别
    new_index_key="${lineArr[0]}""_""${lineArr[1]}"
    # # 在关联数组中不存在
    if [ -z ${new_index_arr[$new_index_key]} ] ; then
      # INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
      new_index_arr[$new_index_key]=${lineArr[@]:2:4}
    else
      new_index_arr[$new_index_key]+=" "
      new_index_arr[$new_index_key]+=${lineArr[@]:2:4}
    fi
  done

  # TABLE_NAME, NON_UNIQUE, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
  for line in $(cat $oldIndexFile)
  do
    lineArr=($(echo $line | tr "\t" "\n"))    
    # 表名_索引类别
    old_index_key="${lineArr[0]}""_""${lineArr[1]}"
    # # 在关联数组中不存在
    if [ -z ${old_index_arr[$old_index_key]} ] ; then
      # INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, INDEX_TYPE
      old_index_arr[$old_index_key]=${lineArr[@]:2:4}
    else
      old_index_arr[$old_index_key]+=" "
      old_index_arr[$old_index_key]+=${lineArr[@]:2:4}
    fi
  done

  for key in ${!new_index_arr[@]}
  do
    local new_index_non_unique=${key:(-1)}
    local tableName=${key/%_${new_index_non_unique}/}
    
    if [ -z ${old_index_arr[$key]} ]; then
      # 不是新增的表
      if [ -z "${addTableDic[$tableName]}" ]; then
        alterSql+=$(combineAddIndex $tableName $new_index_non_unique ${new_index_arr[$key]})
      fi
    else
      if [ ${old_index_arr[$key]} != ${new_index_arr[$key]} ]; then
        alterSql+=$(combineDropIndex $tableName $new_index_non_unique ${old_index_arr[$key]})
        alterSql+=$(combineAddIndex $tableName $new_index_non_unique ${new_index_arr[$key]})
      fi
    fi
  done

  if [ ${#alterSql} -gt 0 ]; then
    echo -e "$alterSql" >> $patchIndexFile
  fi

  unset new_index_arr
  unset old_index_arr
}

compareIndex

unset addTableDic

echo "done."