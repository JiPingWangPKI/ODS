# 一：方案背景
    大数据量的业务项目，经常要做读写分离，从而减小数据库的压力，也为了减小响应耗时，给企业项目数据库搭建一个数据仓库成为重要事项之一，搭建ODS数据仓库最最重要的一件事就是数据同步，但是同步的性能、同步的完整性就是我们值得考虑和深究的了，目前市面上能做数据同步的有很很多，大家普遍能想到是ETL工具，但是这类的工具同步的性能很成为问题，最好的方式就是基于日志同步，下面就来介绍下我们的**ODS方案**；已在上海宝山罗店按此方案搭建一套ODS数据仓库并稳定运行中
# 二：原理介绍
    正如背景介绍，方案中做数据同步基本基于日志同步
[sqlserver的数据同步](https://github.com/JiPingWangPKI/ODS/blob/master/resource/sqlserver同步方案.md)

[mysql的数据同步](https://github.com/JiPingWangPKI/ODS/blob/master/resource/mysql同步方案.md)
    mysql的数据同步
    oracle的数据同步
# 三：实施手册
待完善
# 四：注意
	在resource有ODS相关的各个word，其中ODS方案.docx是早期版本，ODS方案2.0.docx最新版本（已经md化）