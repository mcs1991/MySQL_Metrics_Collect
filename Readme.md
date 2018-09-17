#MySQL_Metrics_Collect

##文档说明

	1.本文档介绍一键收集MySQL诊断信息脚本工具collect_mysql_info的配置使用说明
	2.本工具支持MySQL5.5，5.7版本的信息收集。
	3.由于部分信息借助PT工具收集，所以需要Perl环境

##配置说明

    解压工具包：
    tar -zxvf collect_mysql_info.tar.gz
    配置参数:
    vi collect_mysql_info.sh
    admin_user:mysql super 账户
    admin_password:mysql 密码
    mysql_port:连接MySQL的端口
    mysql_host:连接MySQL的HOST
    mysqlcnf:MySQL配置文件完整路径
    report_path:收集信息汇总路径

##运行脚本

    由于部分信息收集借助PT脚本，所以需要Perl环境
    sh collect_mysql_info.sh

##脚本输出

    输出日志
    工具包根目录下：report.log
    信息收集路径
    report_path参数指定位置
    打包路径：
    report_path参数指定位置下mysql_collect_report_yyyymmddhh24miss.tar.gz
	
