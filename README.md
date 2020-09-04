# db_schema_diff
对比数据库架构，并生成可执行补丁SQL

## 进度

|   分类   |  明细  |       变更        |                    进度                    |
| :------: | :----: | :---------------: | :----------------------------------------: |
| database |        |                   |                                            |
|  table   | column |  add/drop column  |         <input type="checkbox" />          |
|          |        |      默认值       |         <input type="checkbox" />          |
|          |        |     排序规则      |         <input type="checkbox" />          |
|          |        |      字符集       |         <input type="checkbox" />          |
|          |        | index/primary key | <input type="checkbox" checked="checked"/> |
| 存储过程 |        |                   |         <input type="checkbox" />          |

## 使用方法

> 如果可以直接连接数据库，使用 `migrate.sh`；反之，单独使用 `migrate.sh`中的命令

- get_createTable_sql.sh
  - 配置项
    - name="<新版本数据库前缀>"
    - dbIp="<数据库连接IP>"
    - dbPort="<数据库连接Port>"
    - dbAccount="<数据库连接账户>"
    - dbPassword="<数据库连接账户密码>"
    - dbName="<数据库名称>"
- get_new_schema.sh
  - 配置项
    - name="<新版本数据库前缀>"
    - dbIp="<数据库连接IP>"
    - dbPort="<数据库连接Port>"
    - dbAccount="<数据库连接账户>"
    - dbPassword="<数据库连接账户密码>"
    - dbName="<数据库名称>"
  - 输出文件
    - 目录 createTable  包含 create table 语句文件
    - newTableNames.csv 新版本数据库表名列表
    - newColumns.csv  新版本数据库表字段列表
    - newIndexs.csv 新版本数据库表索引列表
- get_old_schema.sh
  - 配置项
    - name="<旧版本数据库前缀>"
    - dbIp="<数据库连接IP>"
    - dbPort="<数据库连接Port>"
    - dbAccount="<数据库连接账户>"
    - dbPassword="<数据库连接账户密码>"
    - dbName="<数据库名称>"
  - 输出文件
    - oldTableNames.csv 旧版本数据库表名列表
    - oldColumns.csv  旧版本数据库表字段列表
    - oldIndexs.csv 旧版本数据库表索引列表
- compare_schema.sh
  - 输出文件
    - patch_column.sql 包含 create table、alter table column 语句
    - patch_index.sql 
    