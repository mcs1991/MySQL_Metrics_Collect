#!/bin/bash

if [ `whoami` != "root" ];then
    echo "请用root用户执行该脚本！"
    exit -
fi

#定义变量
#可配参数
admin_user="root"
admin_password="123456"
mysql_port="3306"
mysql_host="127.0.0.1"
mysqlcnf="/home/mysql/etc/my.cnf"
report_path="/mysql/backup/mysqlReport_"date +%Y%m%d%H%M%S""
#固定参数
curr_path=$(cd "$(dirname "$0")";pwd)
mysql_slowlog="$(mysql -u"$admin_user" -p"$admin_password" -P"$mysql_port" -h"$mysql_host" --show-warnings=false -e "show global variables" |grep -w slow_query_log_file|awk -F ' ' '{print $2}')"
mysql_errorlog="$(mysql -u"$admin_user" -p"$admin_password" -P"$mysql_port" -h"$mysql_host" --show-warnings=false -e "show global variables" --show-warnings=false |grep -w log_error|awk -F ' ' '{print $2}')"
mysql_version="$(mysql -u"$admin_user" -p"${admin_password}" -P"${mysql_port}" -h"${mysql_host}" --show-warnings=false -e "select version()" --show-warnings=false |grep log|awk -F '-' '{print $1}')"
echo -e "\033[32m start collect mysql info... \033[0m"

#清理日志
cd $curr_path
if [ -f report.log ];then
	echo -n "" > report.log
fi

#创建目录
if [ ! -d $report_path ];then
    mkdir -p $report_path
    chown -R mysql.mysql $report_path
fi

#修改权限
cd $curr_path
chmod 775 *

#收集系统运行状态信息（sosreport命令）
sos_command=`rpm -qa | grep sos`
if [ "x$sos_command" != "x" ];then
    echo -e "\033[32m start sosreport... \033[0m" |tee -a $curr_path/report.log
    sosreport --batch -a -k rpm.rpmva=off --tmp-dir=$report_path/os_runtime_info >> $curr_path/report.log 2>&1
    if [ $? -ne 0 ];then
        echo -e "\033[31m exec sosreport error! \033[0m" |tee -a $curr_path/report.log
	fi
else
    echo "该机器没有安装sos命令，OS信息收集失败，请先安装sos命令：yum install sos ！"
    echo "再以root用户sosreport --batch --tmp-dir=$INFO_DIR/os_runtime_info"
fi

#收集最近2天nmon文件
echo -e "\033[32m start copy the last two days nmon file... \033[0m" |tee -a $curr_path/report.log
for nmon_file in $(ls -t /nmon/*.nmon | head -2)
do  
    cp $nmon_file $report_path/
done

#sysctl -a
echo -e "\033[32m start copy sysctl config... \033[0m" |tee -a $curr_path/report.log
sysctl -a > $report_path/sysctl.conf
if [ $? -ne 0 ];then
    echo -e "\033[31m exec copy sysctl config error! \033[0m" |tee -a $curr_path/report.log
fi

#pt-summary
#收集操作系统CPU，内存，磁盘，网络连接信息，包括当前top状态，free -m状态。
cd $curr_path
echo -e "\033[32m start pt-summary... \033[0m" |tee -a $curr_path/report.log
./pt-summary > $report_path/pt-summary_`date +%Y%m%d%H%M%S`.log
if [ $? -ne 0 ];then
    echo -e "\033[31m exec pt-summary error! \033[0m" |tee -a $curr_path/report.log
fi

#收集MySQL配置文件
echo -e "\033[32m start copy my.cnf... \033[0m" |tee -a $curr_path/report.log
cp $mysqlcnf $report_path/my_`date +%Y%m%d%H%M%S`.cnf
        
#收集日志
echo -e "\033[32m start collect logs... \033[0m" |tee -a $curr_path/report.log
cp $mysql_slowlog  $report_path/mysql_slowlog_`date +%Y%m%d%H%M%S`.log
cp $mysql_errorlog $report_path/mysql_errorlog_`date +%Y%m%d%H%M%S`.log
#cat /var/log/messages > $report_path/os_messages_`date +%Y%m%d%H%M%S`.log
cat /var/log/dmesg > $report_path/os_dmesg_`date +%Y%m%d%H%M%S`.log


#收集arp数据
echo -e "\033[32m start collect arp data... \033[0m" |tee -a $curr_path/report.log
arp -a -v -e > $report_path/arp_`date +%Y%m%d%H%M%S`.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect arp data error! \033[0m" |tee -a $curr_path/report.log
fi

#pt-mysql-summary
#收集show global variables，my.cnf，show processlist状态
echo -e "\033[32m start pt-mysql-summary... \033[0m" |tee -a $curr_path/report.log
./pt-mysql-summary --user=$admin_user --password=$admin_password --host=$mysql_host --port=$mysql_port > $report_path/pt-mysql-summary_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m exec pt-mysql-summary error! \033[0m" |tee -a $curr_path/report.log
fi

#pt-show-grants
#收集数据库用户及权限
echo -e "\033[32m start pt-show-grants... \033[0m" |tee -a $curr_path/report.log
./pt-show-grants --user=$admin_user --password=$admin_password --host=$mysql_host --port=$mysql_port > $report_path/pt-show-grants_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
	if [ ${mysql_version:0:3} != "5.5" ];then
		echo -e "\033[31m exec pt-show-grants error! \033[0m" |tee -a $curr_path/report.log
	fi
fi

#pt-slave-find
#获取复制层级关系
echo -e "\033[32m start pt-slave-find... \033[0m" |tee -a $curr_path/report.log
./pt-slave-find --user=$admin_user --password=$admin_password --host=$mysql_host --port=$mysql_port > $report_path/pt-slave-find_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m exec pt-slave-find error! \033[0m" |tee -a $curr_path/report.log
fi

#获取锁信息
echo -e "\033[32m start collect lock info... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "SELECT
r.trx_id AS waiting_trx_id,
r.trx_mysql_thread_id AS waiting_thread,
TIMESTAMPDIFF(
SECOND,
r.trx_wait_started,
CURRENT_TIMESTAMP
) AS wait_time,
r.trx_query AS waiting_query,
l.lock_table AS waiting_table_lock,
b.trx_id AS blocking_trx_id,
b.trx_mysql_thread_id AS blocking_thread,
SUBSTRING(
p. HOST,
1,
INSTR(p. HOST, ':')
) AS blocking_host,
SUBSTRING(p. HOST, INSTR(p. HOST, ':') + 1) AS block_port, 
IF (p.command = \"Sleep\", p.time, 0) AS idle_in_trx, 
b.trx_query AS blcoking_query 
FROM
information_schema.innodb_lock_waits AS w
INNER JOIN information_schema.innodb_trx AS b ON b.trx_id = w.blocking_trx_id
INNER JOIN information_schema.innodb_trx AS r ON r.trx_id = w.requesting_trx_id
INNER JOIN information_schema.innodb_locks AS l ON w.requested_lock_id = l.lock_id
LEFT JOIN information_schema. PROCESSLIST AS p ON p.id = b.trx_mysql_thread_id
ORDER BY
wait_time DESC;" > $report_path/get_lock_info_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect lock info error! \033[0m" |tee -a $curr_path/report.log
fi

#show engine innodb status
echo -e "\033[32m start collect innodb status... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "show engine innodb status\G" > $report_path/get_innodb_status_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect innodb status error! \033[0m" |tee -a $curr_path/report.log
fi

#show slave status
echo -e "\033[32m start collect slave status... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "show slave status\G" > $report_path/show_slave_status_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect slave status error! \033[0m" |tee -a $curr_path/report.log
fi

#show master status
echo -e "\033[32m start collect master status... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "show master status\G" > $report_path/show_master_status_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect master status error! \033[0m" |tee -a $curr_path/report.log
fi

#show global status 3times 5s
echo -e "\033[32m start collect global status... \033[0m" |tee -a $curr_path/report.log
mysqladmin -r -i 5 -c 3 ext -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port > $report_path/show_global_status_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect global status error! \033[0m" |tee -a $curr_path/report.log
fi

#show processlist
echo -e "\033[32m start collect processlist... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "show processlist\G" > $report_path/show_processlist_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect processlist error! \033[0m" |tee -a $curr_path/report.log
fi

#show global variables
echo -e "\033[32m start collect global variables... \033[0m" |tee -a $curr_path/report.log
mysql -A -u$admin_user -p$admin_password -h$mysql_host -P$mysql_port --connect_timeout=30 -e "show global variables\G" > $report_path/show_global_variables_`date +%Y%m%d%H%M%S`.log 2>>$curr_path/report.log
if [ $? -ne 0 ];then
    echo -e "\033[31m collect global variables error! \033[0m" |tee -a $curr_path/report.log
fi

#打包
echo -e "\033[32m start Packing data... \033[0m" |tee -a $curr_path/report.log
cd $report_path
tar -zcvf mysql_collect_report_`date +%Y%m%d%H%M%S`.tar.gz * >/dev/null 2>&1
if [ $? -ne 0 ];then
    echo -e "\033[31m Packing data error! \033[0m" |tee -a $curr_path/report.log
fi
echo -e "\033[32m collect mysql info complete \033[0m"
