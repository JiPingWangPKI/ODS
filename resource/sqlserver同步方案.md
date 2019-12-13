# 一：前言
	针对sqlserver的同步方案，有两种情况，有主键表的同步，和无主键表的同步
# 二：有主键表的同步方法
	可以用sqlserver的发布订阅基于（这就是基于日志同步对被同步的表性能影响很小）
[sqlserver的发布订阅手册](https://www.cnblogs.com/xiaoping1993/p/8794192.html)
	
# 三：无主键表的同步方法
## 3.1 背景介绍
	对sqlserver做数据库同步的时候，由于医院服务器和数据库版本的限制，选择了用发布订阅处理数据库同步，但是这个方式只能处理有主键的表，对于无主键的表不能处理，基于这种情况，只能选择第三方工具，经过调研发现市面上的ETL工具可解决问题，之后选了一个与同是微软提供的与sqlserver同源的ETL同居SSIS就可以用，经过测试，发现他可以处理小表，但是对于数据量大的表处理起来会很费时间，所以我基于SSIS无主键表的同步规则写了一个脚本来做数据库无主键表的同步。到这里sqlserver的数据库同步方式：方法订阅处理有主键表+模拟SSIS的脚本处理无主键表。
## 3.2 技术原理
	通过对比同步表和被同步表之间的异同，做同步的表多的列删除少的列添加。
## 3.3 实施方案
	1.如果待同步的数据库不在同一个服务器上，需要建立一个链接服务器，这样方便在一个服务器上定位到两个数据库
	2.新创建一个数据库PKIODS作为处理无主键表同步的数据库同时记录日志，执行下面同步脚本
	3.接下来做一个计划任务每10min执行一次 SyncDBNoKeyTables脚本
		执行的脚本类似：
		EXEC	@return_value = [dbo].[SyncDBNoKeyTables]
		@DBNameFrom = N'test',
		@DBNameTo = N'test_1',
		@uniqueId = N'1',
		@logTable = N'test_1.dbo.NoKeyTableLogs'
		让他在计划任务中每10min执行一次
	步骤2脚本"无主键数据表同步"执行完后会生成一个存储过程SyncDBNoKeyTables
	@DBNameFrom varchar(100) = '[172.26.11.18].test',//源数据库
	@DBNameTo varchar(100) = 'test',//目标数据库，需要先自行创建清空
	@uniqueId varchar(20) = '1',//同步唯一值避免与其他同步线程产生变量上的相同	
	@logTable varchar(100) = 'test.dbo.NoKeyTableLogs'//日志存放的位置
<details>
<summary>无主键数据表同步</summary>
<pre><code>
USE [BAGL2012]
GO
/****** 
Object:  StoredProcedure [dbo].[SyncDBNoKeyTables]    
Script Date: 2019/7/31 11:09:36 
author：王吉平
******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--存储过程同步两个数据库所有无主键表
ALTER procedure [dbo].[SyncDBNoKeyTables]
@DBNameFrom varchar(100) = '[172.26.11.18].test',
@DBNameTo varchar(100) = 'test',
@uniqueId varchar(20) = '1',
@logTable varchar(100) = 'test.dbo.NoKeyTableLogs'
as
begin
--SQL查找数据库中所有没有主键的数据表脚本
--运行脚本后在消息中可能会显示下面现象中的一种：
--(2)当前数据表[数据表名]没有主键(则可方便找到没主键的数据表)
--如果指定的日志表不存在就重新创建
if not exists (select * from dbo.sysobjects where id = object_id(@logTable) and OBJECTPROPERTY(id, N'IsUserTable') =1)
	begin
		--创建这个表
		declare @createLogsql nvarchar(max) =''
		set @createLogsql = '
			CREATE TABLE '+@logTable+'(
				[id] [int] IDENTITY(1,1) NOT NULL,
				[dbFrom] [varchar](100) NULL,
				[dbTo] [varchar](100) NULL,
				[tableName] [varchar](100) NULL,
				[tableColumn] [varchar](50) NULL,
				[columnType] [varchar](50) NULL,
				[time] [datetime] NULL,
				[message] [varchar](max) NULL,
				[messageType] [int] NULL,
			 CONSTRAINT [PK_NoKeyTableLogs] PRIMARY KEY CLUSTERED 
			(
				[id] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
		'
		exec(@createLogsql)
	end
	declare @insertLogsql nvarchar(max) ='insert into '+@logTable+'(dbFrom,dbTo,tableName,tableColumn,columnType,time,message,messageType) values(@dbFrom,@dbTo,@tableName,@tableColumn,@columnType,@time,@message,@messageType)'
	declare @now varchar(100) =getdate()
	exec sp_executesql @insertLogsql,N'@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int',@DBNameFrom,@DBNameTo,'','','',@now,'开始同步数据库',0;
declare @sql1 nvarchar(max),@sql2 nvarchar(max)
set @sql1 = 'declare @TableName'+@uniqueId+' nvarchar(2000),@WarnMessageInner'+@uniqueId+' nvarchar(max)=''''
	declare mycursor'+@uniqueId+' cursor for select name from '+@DBNameFrom+'.dbo.SysObjects WHERE xtype=''U'' order by name
	--打开游标
	open mycursor'+@uniqueId+'
	--从游标里取出数据赋值到我们刚才声明的数据表名变量中
	fetch next from mycursor'+@uniqueId+' into @TableName'+@uniqueId+'
	while (@@fetch_status=0)
		begin 
		declare @insertLogsql'+@uniqueId+' nvarchar(max) =''insert into '+@logTable+'(dbFrom,dbTo,tableName,tableColumn,columnType,time,message,messageType) values(@dbFrom,@dbTo,@tableName,@tableColumn,@columnType,@time,@message,@messageType)''
		declare @now'+@uniqueId+' varchar(100) =getdate()
		--判断当前数据表是否存在主键
		IF NOT EXISTS (select * from '+@DBNameFrom+'.information_schema.key_column_usage where TABLE_NAME=@TableName'+@uniqueId+')
			begin
				--先判断是否备份目标表是否已存在
				declare @num'+@uniqueId+' int
				select @num'+@uniqueId+'=count(1) from '+@DBNameTo+'..sysobjects where xtype=''U'' and name =@TableName'+@uniqueId+'
				if @num'+@uniqueId+'>0 --备份表存在
					begin
						set @now'+@uniqueId+' =getdate()
						exec sp_executesql @insertLogsql'+@uniqueId+',N''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'','''+@DBNameFrom+''','''+@DBNameTo+''',@TableName'+@uniqueId+','''','''',@now'+@uniqueId+',''开始同步数据表...'',0;
						--处理没有主键表，找到其所有列 
						--定义游标遍历查询的列集合
						declare myColumnCursor'+@uniqueId+' cursor for select column_name,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH from '+@DBNameFrom+'.information_schema.columns where table_name=@TableName'+@uniqueId+'
						--定义列信息变量
						declare @name'+@uniqueId+' varchar(50),@type'+@uniqueId+' varchar(50),@length'+@uniqueId+' varchar(10)
						--定义同步脚本字符串中需要的组合列字符串
						declare @sync1'+@uniqueId+' varchar(max)='''',@sync2'+@uniqueId+' varchar(max)='''',@sync3'+@uniqueId+' varchar(max)='''',@sync4'+@uniqueId+' varchar(max)='''',@sync5'+@uniqueId+' varchar(max)='''',@sync6'+@uniqueId+' varchar(max)='''',@sync7'+@uniqueId+' varchar(max)='''',@sync8'+@uniqueId+' varchar(max)='''',@sync9'+@uniqueId+' varchar(max)='''',@sync10'+@uniqueId+' varchar(max)='''',@sync11'+@uniqueId+' varchar(max)='''',@sync12'+@uniqueId+' varchar(max)='''',@sync13'+@uniqueId+' varchar(max)='''',@sync14'+@uniqueId+' varchar(max)='''',@sync15'+@uniqueId+' varchar(max)=''''
						--定义一个变量0：表示字段类型非Text.Ntext,image;1:表示是的
						declare @isTextImageType'+@uniqueId+' int =0
						--打开列游标
						open myColumnCursor'+@uniqueId+'
						--从游标中取出数据赋值到三个列信息变量中
						fetch next from myColumnCursor'+@uniqueId+' into @name'+@uniqueId+',@type'+@uniqueId+',@length'+@uniqueId+'
						while (@@fetch_status=0)
							begin
								--重新复制数据类型@type
								set @isTextImageType'+@uniqueId+'=0
								if @length'+@uniqueId+'=-1
									begin
										set @type'+@uniqueId+'=@type'+@uniqueId+'+''(max)''
									end
								if @length'+@uniqueId+'>0 and @length'+@uniqueId+'<=8000
									begin
										set @type'+@uniqueId+'=@type'+@uniqueId+'+''(''+@length'+@uniqueId+'+'')''
									end
								if @type'+@uniqueId+'=''image''
									begin
										set @type'+@uniqueId+' = ''varbinary(max)''
										set @isTextImageType'+@uniqueId+'=1
									end
								if @type'+@uniqueId+'=''ntext''
									begin
										set @type'+@uniqueId+' = ''nvarchar(max)''
										set @isTextImageType'+@uniqueId+'=1
									end
								if @type'+@uniqueId+'=''text''
									begin
										set @type'+@uniqueId+' = ''varchar(max)''
										set @isTextImageType'+@uniqueId+'=1
									end
								--去除空格--
								set @name'+@uniqueId+'=ltrim(rtrim(@name'+@uniqueId+'))
								set @sync1'+@uniqueId+'=@sync1'+@uniqueId+'+''a.''+@name'+@uniqueId+'+'' as ''+@name'+@uniqueId+'+'',''
								if @name'+@uniqueId+'!=''timestamp''
									begin
										set @sync2'+@uniqueId+'=@sync2'+@uniqueId+'+''b.''+@name'+@uniqueId+'+'' as ''+@name'+@uniqueId+'+''Another,''
										set @sync7'+@uniqueId+'=@sync7'+@uniqueId+'+''@''+@name'+@uniqueId+'+''Another ''+ @type'+@uniqueId+'+'',''
										set @sync9'+@uniqueId+'=@sync9'+@uniqueId+'+''@''+@name'+@uniqueId+'+''Another,''
										set @sync12'+@uniqueId+'=@sync12'+@uniqueId+'+@name'+@uniqueId+'+''Another is null and ''
										if @isTextImageType'+@uniqueId+'=0
											begin
												set @sync14'+@uniqueId+'=@sync14'+@uniqueId+'+''(''+@name'+@uniqueId+'+'' is null or ''+@name'+@uniqueId+'+''=@''+@name'+@uniqueId+'+''Another) and ''
											end
									end
									else begin
										set @now'+@uniqueId+' =getdate()
										exec sp_executesql @insertLogsql'+@uniqueId+',N''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'','''+@DBNameFrom+''','''+@DBNameTo+''',@TableName'+@uniqueId+',@name'+@uniqueId+',@type'+@uniqueId+',@now'+@uniqueId+',''表中存在timestamp类型'',1;
										set @WarnMessageInner'+@uniqueId+' = @WarnMessageInner'+@uniqueId+'+''表''+@TableName'+@uniqueId+'+''存在timestamp类型：''+@name'+@uniqueId+'+'' ''+@type'+@uniqueId+'+char(10)
									end
								set @sync8'+@uniqueId+'=@sync8'+@uniqueId+'+''@''+@name'+@uniqueId+'+'',''
								if @isTextImageType'+@uniqueId+'=0
									begin
										set @sync3'+@uniqueId+'=@sync3'+@uniqueId+'+''((a.''+@name'+@uniqueId+'+'' = b.''+@name'+@uniqueId+'+'') or (a.''+@name'+@uniqueId+'+'' is null and b.''+@name'+@uniqueId+'+'' is null))  and ''
									end
									else begin
										set @now'+@uniqueId+' =getdate()
										exec sp_executesql @insertLogsql'+@uniqueId+',N''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'','''+@DBNameFrom+''','''+@DBNameTo+''',@TableName'+@uniqueId+',@name'+@uniqueId+',@type'+@uniqueId+',@now'+@uniqueId+',''表中存在Text,Image,NText等类型字段'',1;
										set @WarnMessageInner'+@uniqueId+' = @WarnMessageInner'+@uniqueId+'+''表''+@TableName'+@uniqueId+'+''存在Text,Image,NText等类型字段：''+@name'+@uniqueId+'+'' ''+@type'+@uniqueId+'+char(10)
									end
								set @sync4'+@uniqueId+'=@sync4'+@uniqueId+'+''a.''+@name'+@uniqueId+'+'' is null and ''
								set @sync5'+@uniqueId+'=@sync5'+@uniqueId+'+''b.''+@name'+@uniqueId+'+'' is null and ''
								set @sync6'+@uniqueId+'=@sync6'+@uniqueId+'+''@''+@name'+@uniqueId+'+'' ''+ @type'+@uniqueId+'+'',''
								set @sync13'+@uniqueId+'=@sync13'+@uniqueId+'+''@''+@name'+@uniqueId+'+'' is not null and ''
								fetch next from myColumnCursor'+@uniqueId+' into @name'+@uniqueId+',@type'+@uniqueId+',@length'+@uniqueId+'
							end
						close myColumnCursor'+@uniqueId+'
						deallocate myColumnCursor'+@uniqueId+'
						--开始拼接同步数据表字符串
						--重新处理这几个变量
						set @sync1'+@uniqueId+' = left(@sync1'+@uniqueId+',len(@sync1'+@uniqueId+')-1)
						set @sync2'+@uniqueId+' = left(@sync2'+@uniqueId+',len(@sync2'+@uniqueId+')-1)
						set @sync3'+@uniqueId+' = left(@sync3'+@uniqueId+',len(@sync3'+@uniqueId+')-4)
						set @sync4'+@uniqueId+' = left(@sync4'+@uniqueId+',len(@sync4'+@uniqueId+')-4)
						set @sync5'+@uniqueId+' = left(@sync5'+@uniqueId+',len(@sync5'+@uniqueId+')-4)
						set @sync6'+@uniqueId+' = left(@sync6'+@uniqueId+',len(@sync6'+@uniqueId+')-1)
						set @sync7'+@uniqueId+' = left(@sync7'+@uniqueId+',len(@sync7'+@uniqueId+')-1)
						set @sync8'+@uniqueId+' = left(@sync8'+@uniqueId+',len(@sync8'+@uniqueId+')-1)
						set @sync9'+@uniqueId+' = left(@sync9'+@uniqueId+',len(@sync9'+@uniqueId+')-1)
						set @sync10'+@uniqueId+' = replace(@sync4'+@uniqueId+',''a.'','''')
						set @sync11'+@uniqueId+' = replace(replace(@sync9'+@uniqueId+',''@'',''''),''Another'','''')
						set @sync12'+@uniqueId+' = left(@sync12'+@uniqueId+',len(@sync12'+@uniqueId+')-4)
						set @sync13'+@uniqueId+' = left(@sync13'+@uniqueId+',len(@sync13'+@uniqueId+')-4)
						set @sync14'+@uniqueId+' = left(@sync14'+@uniqueId+',len(@sync14'+@uniqueId+')-4)
						set @sync15'+@uniqueId+' = replace(@sync9'+@uniqueId+',''Another'','''')
						--内部执行sql语句
						exec(''
							SELECT ''+@sync1'+@uniqueId+'+'',''+@sync2'+@uniqueId+'+'' into #temp'+@uniqueId+' from '+@DBNameFrom+'.dbo.[''+@TableName'+@uniqueId+'+''] a full join '+@DBNameTo+'.dbo.[''+@TableName'+@uniqueId+'+''] b on ''+@sync3'+@uniqueId+'+'' where (''+@sync4'+@uniqueId+'+'') or (''+@sync5'+@uniqueId+'+'');
							DECLARE 
							''+@sync6'+@uniqueId+'+'',''+@sync7'+@uniqueId+'+''
							 --处理结果的变量
							DECLARE C_callInfo'+@uniqueId+' CURSOR FOR SELECT * from #temp'+@uniqueId+' where (''+@sync10'+@uniqueId+'+'') or (''+@sync12'+@uniqueId+'+'');
							OPEN C_callInfo'+@uniqueId+'
							FETCH NEXT FROM C_callInfo'+@uniqueId+' INTO  ''+@sync8'+@uniqueId+'+'',''+@sync9'+@uniqueId+'+''    --此处变量位置和查询的列要对应类型
							WHILE(@@FETCH_STATUS=0) 
							 BEGIN
							  if ''+@sync13'+@uniqueId+'+''
								begin
									--需要将这个结果列插入备份表
									insert into '+@DBNameTo+'.dbo.[''+@TableName'+@uniqueId+'+''](''+@sync11'+@uniqueId+'+'') values(''+@sync15'+@uniqueId+'+'')
								end
								else begin
									--需要在备份表中删除这一列
									delete from '+@DBNameTo+'.dbo.[''+@TableName'+@uniqueId+'+''] where ''+@sync14'+@uniqueId+'+''
								end
							  FETCH NEXT FROM C_callInfo'+@uniqueId+' INTO  ''+@sync8'+@uniqueId+'+'',''+@sync9'+@uniqueId+'+'' --下一条
							 END 
							CLOSE C_callInfo'+@uniqueId+' 
							DEALLOCATE C_callInfo'+@uniqueId+'
							drop table #temp'+@uniqueId+'
							declare @now'+@uniqueId+' varchar(100) =getdate()
							declare @insertLogsql'+@uniqueId+' nvarchar(max)=''''insert into '+@logTable+'(dbFrom,dbTo,tableName,tableColumn,columnType,time,message,messageType) values(@dbFrom,@dbTo,@tableName,@tableColumn,@columnType,@time,@message,@messageType)''''
							exec sp_executesql @insertLogsql'+@uniqueId+',N''''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'''','''''+@DBNameFrom+''''','''''+@DBNameTo+''''',''+@TableName'+@uniqueId+'+'','''''''','''''''',@now'+@uniqueId+',''''开始同步数据表结束'''',0;
						'')
					end'
				set @sql2 = '
					else begin --备份表不存在需要重新创建同时录入数据
							set @now'+@uniqueId+' =getdate()
							exec sp_executesql @insertLogsql'+@uniqueId+',N''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'','''+@DBNameFrom+''','''+@DBNameTo+''',@TableName'+@uniqueId+','''','''',@now'+@uniqueId+',''开始初始化表...'',0;
						print ''开始初始化表：''+@TableName'+@uniqueId+'+''....''
						declare @sqlInner11'+@uniqueId+' varchar(max) =''''
						set @sqlInner11'+@uniqueId+' = ''
							select * into '+@DBNameTo+'.dbo.[''+@TableName'+@uniqueId+'+''] from '+@DBNameFrom+'.dbo.[''+@TableName'+@uniqueId+'+'']
							declare @now'+@uniqueId+' varchar(100) =getdate()
							declare @insertLogsql'+@uniqueId+' nvarchar(max)=''''insert into '+@logTable+'(dbFrom,dbTo,tableName,tableColumn,columnType,time,message,messageType) values(@dbFrom,@dbTo,@tableName,@tableColumn,@columnType,@time,@message,@messageType)''''
							exec sp_executesql @insertLogsql'+@uniqueId+',N''''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'''','''''+@DBNameFrom+''''','''''+@DBNameTo+''''',@TableName'+@uniqueId+','''''''','''''''',@now'+@uniqueId+',''''初始化表结束...'''',0;
							''
						begin try
							exec(@sqlInner11'+@uniqueId+')
						end try
						begin catch
							set @now'+@uniqueId+' =getdate()
							exec sp_executesql @insertLogsql'+@uniqueId+',N''@dbFrom varchar(100),@dbTo varchar(100),@tableName varchar(50),@tableColumn varchar(50),@columnType varchar(50),@time datetime,@message varchar(max),@messageType int'','''+@DBNameFrom+''','''+@DBNameTo+''',@TableName'+@uniqueId+','''','''',@now'+@uniqueId+',''+ERROR_MESSAGE()+'',0;
							set @WarnMessageInner'+@uniqueId+'=@WarnMessageInner'+@uniqueId+'+ERROR_MESSAGE()+char(10)
						end catch
					end
			end
		--用游标去取下一条记录 
		fetch next from mycursor'+@uniqueId+' into @TableName'+@uniqueId+'
	end
	--@WarnMessageInner'+@uniqueId+'--所有内部异常
	close mycursor'+@uniqueId+'
	deallocate mycursor'+@uniqueId+'
'
--exec @sql
exec (@sql1+@sql2)
--脚本代码结束
print('同步数据库'+@DBNameFrom+'结束')
end
</code></pre>
</details>
## 3.4 注意
	脚本性能还是很好的，100个无主键表保持在2min左右同步时间
	目前版本存在部门缺点：
	1）	对于被同步无主键表中如果包含了xml字段，无法同步，但会记录在日志文件中且不会影响同步进程，待后续找到解决方法后处理掉
	2）	对于被同步无主键表中如果包含了字段长度超过8000长度的，如image,text,ntext，脚本中已经做了特殊处理让他们作为varbinary(max),varchar(max)，nvarchar(max)替代，理论上这样处理做同步时就不会存在误差，但由于在sqlserver2012之后版本中测试可知max并没有将上述替换类型长度变为超过8000，达到理论上的2G长度，依旧是8000最大长度，所有如果被同步表中如果包含image，text等长度大于8000字段可能会存在同步误差。同样的对于此类表会留有记录在日志表中，待后续找到解决方法之后处理掉
## 3.5 特殊情况的特殊处理
	由于前面提供的无主键同步方案存在对于包含xml，image,text等类型的无主键表同步不正常的问题，想了一个解决方案：
	1）	包含xml字段无主键表：
	对于这种情况，我们可以通过编写java脚本（想要融入前面编写的脚本中可在其中嵌入触发器，发现xml的问题就执行这个java脚本），用java连接两个数据库，全部转移到新库，注意这里同步过来的表名后面加上_copy，通过结束后，再做判断辛苦库中是否已经有了表，有删除，没有将复制过来的_copy去掉_copy无缝切换。
	2）	包含image,text等无主键表
	由于现在还未解决掉varchar(max)长度还是8000的问题，这里还使用copy转正方式无缝同步数据库（同样这段处理代码想要嵌入之前脚本，也需要一个触发器，当发现正在处理这个表，就使用新的处理方式处理）：select into 到新的库表名换为_copy，等copy结束再判断库中是否有表，没有的话直接重命名表名_copy，有的话删除表，将_copy表转正重命名去掉_copy



	
	