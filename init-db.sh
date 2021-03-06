#!/bin/bash

dbstart=`expr \`date +%s%N\` / 1000000`
echo "  数据库类型: $DB_TYPE"

#### SQL初始化
if [[ -z "$DB_TYPE" ||  "$DB_TYPE" = "mysql" ]]; then

  echo "  MYSQL数据库初始化开始..."
  
  SQL_PATH="$JUSTEP_HOME/sql"
  mkdir -p $SQL_PATH
  LOG_PATH="$SQL_PATH/sql_`date +%Y%m%d%H%M%S`.log"
  load_script(){
    TMP="tmp_script"
    echo "DROP DATABASE IF EXISTS x5;" >>$TMP
    echo "CREATE DATABASE x5;" >>$TMP
    echo "USE x5;" >>$TMP
    echo "SET FOREIGN_KEY_CHECKS=0;" >>$TMP
    echo "SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';" >>$TMP
    SQL_FILES=`ls -A $1/*.sql 2> /dev/null`
    for FILE_NAME in $SQL_FILES;do
      echo "source $FILE_NAME;" >>$TMP
    done
    echo "SET FOREIGN_KEY_CHECKS=1;" >>$TMP
    echo "SET SQL_MODE='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';" >>$TMP
    echo "commit;" >>$TMP
    echo "quit" >>$TMP
    echo "" >>$TMP
  
    testsql=( ./mysql -hdatabase -uroot -px5 )
    for i in {9..0}; do
      if echo 'SELECT 1' | ${testsql[@]} &> /dev/null; then
        break
      fi
      echo '  连接数据库失败，5秒后重试...'
      sleep 5 
    done
  
    if [ "$i" = 0 ]; then
      error '  数据库连接失败，请检查部署环境' 1
    fi
  
    #START_TIME=$(date "+%s")
    ./mysql --default-character-set=utf8 -hdatabase -uroot -px5 -ve "source $TMP" >$LOG_PATH 2>&1
    ERROR=$?
    if [ "$ERROR" -eq "0" ]; then
      #echo "  数据库初始化成功！共计用时: " `expr $(date "+%s") - ${START_TIME}` " 秒"
      echo "  MYSQL初始化成功！"
    else
      head $LOG_PATH
      error "  [$ERROR]MYSQL初始化失败" 1
    fi
  }
  
  mkdir -p $SQL_PATH
  cd $SQL_PATH
  echo "  获取mysql客户端..."
  curl -s -f $PRODUCT_URL/mysql/5.6/mysql -o mysql
  chmod a+x mysql
  
  load_script $SQL_PATH
  dbmig=`expr \`date +%s%N\` / 1000000`
  echo "  数据库SQL部分初始化完毕. 耗时$[ dbstart - inipgrst ]毫秒"

elif [[ "$DB_TYPE" = "pgsql" ]]; then
#### 启动pgrest
  echo "  开始调用initpostgrest(schemaid: $POSTGREST_SCHEMAID)..."
  for i in {9..0}; do
    ret=`curl -sf -o /dev/null -w "%{http_code}" --url "http://$APP_SRV_NAME:$APP_SRV_PORT/x5/UI2/system/deploy/common/initPostgrest.j?postgrest_schemaid=$POSTGREST_SCHEMAID"`
    echo "  返回: $ret"
    if [[ "x$ret" =~ x20* || "x$ret" =~ x50* ]]; then
      break
    fi
    echo '  initpostgrest失败，3秒后重试...'
    sleep 3
  done
  inipgrst=`expr \`date +%s%N\` / 1000000`
  echo "  调用initpostgrest完毕. 耗时$[ inipgrst - dbstart ]毫秒"

#### migrate.jar执行
  echo "  数据库migrate部分初始化开始..."
  
  if [ -z "$DB_DRIVER_CLASS_NAME" ]; then
    error '  请设置DB_DRIVER_CLASS_NAME环境变量' 1
  else
    #echo "DB_DRIVER_CLASS_NAME: $DB_DRIVER_CLASS_NAME"
    export DB_DRIVER_CLASS_NAME
  fi
  if [ -z "$DB_USERNAME" ]; then
    error '  请设置DB_USERNAME环境变量' 1
  else
    #echo "DB_USERNAME: $DB_USERNAME"
    export DB_USERNAME
  fi
  if [ -z "$DB_PASSWORD" ]; then
    error '  请设置DB_PASSWORD环境变量' 1
  else
    #echo "DB_PASSWORD: $DB_PASSWORD"
    export DB_PASSWORD
  fi
  if [ -z "$DB_URL" ]; then
    error '  请设置DB_URL环境变量' 1
  else
    #echo "DB_URL: $DB_URL"
    export DB_URL
  fi
  if [ -z "$DB_SCHEMA" ]; then
    error '  请设置DB_SCHEMA环境变量' 1
  else
    #echo "DB_SCHEMA: $DB_SCHEMA"
    export DB_SCHEMA
  fi
  if [ -z "$JUSTEP_HOME" ]; then
    error '  请设置JUSTEP_HOME环境变量' 1
  else
    #echo "JUSTEP_HOME: $JUSTEP_HOME"
    export JUSTEP_HOME
  fi
  jarpath=/usr/local/db-init
  cd $jarpath
  java -jar migrate.jar 
  cd -
  dbmig=`expr \`date +%s%N\` / 1000000`
  echo "  数据库migrate部分初始化完毕. 耗时$[ dbmig - inipgrst ]毫秒"
else
  echo "  未知的数据库类型! 退出数据库初始化."
  UNKNOWN_TYPE="true"
fi

if [[ -z "$UNKNOWN_TYPE" ]]; then
  #### 生成datasource.xml
  
  echo "  生成$JUSTEP_HOME/conf/datasource.xml开始..."
  
  xmlpath=/usr/local/db-init/datasource.xml
  content=`cat $xmlpath` 
  content=${content//##DB_DRIVER_CLASS_NAME##/$DB_DRIVER_CLASS_NAME}
  content=${content//##DB_USERNAME##/$DB_USERNAME}
  content=${content//##DB_PASSWORD##/$DB_PASSWORD}
  DB_URL_ESCAPE=${DB_URL//&/&amp;}
  content=${content//##DB_URL##/$DB_URL_ESCAPE}
  content=${content//##DB_SCHEMA##/$DB_SCHEMA}
  #echo $content
  mkdir -p $JUSTEP_HOME/conf
  
  echo $content > $JUSTEP_HOME/conf/datasource.xml
  
  xmlgen=`expr \`date +%s%N\` / 1000000`
  echo "  datasource.xml生成完毕. 耗时$[ xmlgen - dbmig ]毫秒"
fi
