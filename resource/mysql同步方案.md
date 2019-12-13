# 前言
	mysql的不存在有无主键的问题，用mysql本身基于日志同步机制“mysql主从同步”即可
# mysql 主从同步手册
## 1. 主从复制原理：
　　slave（从mysql数据库）通过I/O线程读取Master（主mysql数据库）,读取binary log events 并写入中继日志（relay log）,slave 执行中继日志中事件，将中继日志中日志记录一条条执行到本地存储，从而通过这两个线程主从数据同步
## 2.步骤
### 1）准备2台机器（master：192.168.56.101；slave：192.168.56.102）
### 2）在master主机
	2.1 修改C:\ProgramData\MySQL\MySQL Server 8.0\my.ini文件（这个文件一般都在这个位置，修改完此文件都需要重启mysql服务）
		修改：server-id=1（这里的id值需与slave中相应位置不同，表明不同服务）
		修改：log-bin="WIN-PO1I559INRE-bin"（这里填写路径，开启了binlog机制同时配置log-bin日志路径在相对路径WIN-PO1I559INRE-bin下）
		(binlog_format=mixed--两种方式混合
		binlog-do-db = testdb --做主从同步的数据库名
		binlog-ignore-db = mysql --指定同步的数据库
		binlog-ignore-db = performance_schema --指定忽略的数据库
		binlog-ignore-db = information_schema)这几个配置可做更细节的配置
		重启mysql:   net restart mysql可以在services页面手动重启mysql服务)，重启后即可看到在如下路径新增了***-bin.00002,这就是日志文件
![mysql主从复制1](https://github.com/JiPingWangPKI/ODS/raw/master/resource/image/mysql主从复制1.jpg)
	2.2 在master主机上，为slave配置用户名，密码，同时赋予slave权限
		创建用户：create user 'repl'@'192.168.56.102' identified by '!@34QWer';（其中192.168.56.102是slave的ip地址，这样在slave主机中就可以通过repl访问master上的日志文件了）
		分配权限：grant replication slave on *.* to 'repl'@'192.168.56.102';
		让创建用户分配权限生效需要执行：flush privileges;
### 3）在slave主机
	3.1 修改C:\ProgramData\MySQL\MySQL Server 8.0\my.ini文件（这个文件一般都在这个位置，修改完此文件都需要重启mysql服务）
		修改：server-id=2（不能与master的server-id一样）
		修改：如果log-bin也被配置上了需要手动注释上，这里不需要配置
		重启mysql: 可以在services页面手动重启mysql服务
	3.2 开始配置slave能够拿到想要监听的master日志文件（bin-log）,执行以下命令
		执行stop slave 先停止同步操作；
		在修改slave主机的master为我们想要监听的master这里是（192.168.56.101）：
		CHANGE MASTER TO MASTER_HOST='192.168.56.101', MASTER_USER='repl', MASTER_PASSWORD='!@34QWer', MASTER_LOG_FILE='WIN-PO1I559INRE-bin.000004', MASTER_LOG_POS=1098;
		(192.168.56.101：主机master地址，repl：master主机上分配的用户，master-log-file：master上的日志文件名称可通过在master主机上执行show master status 查看到日志文件名称和下面一个变量postion值)
		配置完成后，执行start slave 开始同步操作。
### 4）验证是否配置成功
	在slave机器上执行：show slave status;
![mysql主从复制1](https://github.com/JiPingWangPKI/ODS/raw/master/resource/image/mysql主从复制2.jpg)
	发现这两个字段是yes；
	在master机器上执行：show processlist;看到下面内容
![mysql主从复制1](https://github.com/JiPingWangPKI/ODS/raw/master/resource/image/mysql主从复制3.jpg)
	最后在测试一下，即可判断主从复制做好！
### 5）可能出现的错误
	当执行show slave status;后 其中Slave_IO_Running 为running时，说明没有配置成功，处理，具体参考
	https://cloud.tencent.com/info/3ce6fb6c2d65bd337b37e591b46a3557.html
### 6）可能存在的风险
	如果他们mysql服务器没有做主从配置，可能需要重启他们的服务器因为修改了my.ini文件后只有重启mysql服务后才能生效；且由于主服务器已经运行一段时间，同步之前需要将主服务之前数据手动迁移到从服务器，然后主服务不做操作情况下，获得log_file_pos的值，
## 3.衍生多主一从复制
	如果遇到这样的场景：多个master想要同步到一个slave上，可以参考：https://www.cnblogs.com/xuanzhi201111/p/5151666.html；
	大致总结：与上面描述不同之处在于：
	1）同步之前修改MySQL存储master-info和relay-info的方式，即从文件存储改为表存储，在my.cnf里添加下面两个参数
	master_info_repository=TABLE；relay_log_info_repository=TABLE
	2）在slave上配置master时命令增加了之地的master唯一号名字
	类似：CHANGE MASTER TO MASTER_HOST='192.168.10.128',MASTER_USER='repl', MASTER_PASSWORD='123456',MASTER_LOG_FILE='Master_1-bin.000001',MASTER_LOG_POS=1539 FOR CHANNEL 'Master_1'; 
	


