USE [test]
GO
/****** Object:  StoredProcedure [dbo].[SyncDBNoKeyTables]    Script Date: 2019/7/23 17:54:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--存储过程同步两个数据库所有无主键表
ALTER procedure [dbo].[SyncDBNoKeyTables]
@DBNameFrom varchar(100) = '[172.26.11.18].test',
@DBNameTo varchar(100) = 'test',
@uniqueId varchar(20) = '1'
as
begin
--SQL查找数据库中所有没有主键的数据表脚本
--运行脚本后在消息中可能会显示下面现象中的一种：
--(2)当前数据表[数据表名]没有主键(则可方便找到没主键的数据表)
print '开始同步数据库'+@DBNameFrom+'....'
declare @sql varchar(max)
set @sql = 'declare @TableName'+@uniqueId+' nvarchar(2000)
	declare mycursor'+@uniqueId+' cursor for select name from '+@DBNameFrom+'.dbo.SysObjects WHERE xtype=''U'' order by name
	--打开游标
	open mycursor'+@uniqueId+'
	--从游标里取出数据赋值到我们刚才声明的数据表名变量中
	fetch next from mycursor'+@uniqueId+' into @TableName'+@uniqueId+'
	while (@@fetch_status=0)
		begin 
		--判断当前数据表是否存在主键
		IF NOT EXISTS (select * from '+@DBNameFrom+'.information_schema.key_column_usage where TABLE_NAME=@TableName'+@uniqueId+')
			begin
				--先判断是否备份目标表是否已存在
				declare @num'+@uniqueId+' int
				select @num'+@uniqueId+'=count(1) from '+@DBNameTo+'..sysobjects where xtype=''U'' and name =@TableName'+@uniqueId+'
				if @num'+@uniqueId+'>0 --备份表存在
					begin
						print ''开始同步表''+@TableName'+@uniqueId+'+''....''
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
								set @sync8'+@uniqueId+'=@sync8'+@uniqueId+'+''@''+@name'+@uniqueId+'+'',''
								if @isTextImageType'+@uniqueId+'=0
									begin
										set @sync3'+@uniqueId+'=@sync3'+@uniqueId+'+''((a.''+@name'+@uniqueId+'+'' = b.''+@name'+@uniqueId+'+'') or (a.''+@name'+@uniqueId+'+'' is null and b.''+@name'+@uniqueId+'+'' is null))  and ''
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
							print ''''同步表结束：''+@TableName'+@uniqueId+'+''''''
						'')
					end
					else begin --备份表不存在需要重新创建同时录入数据
						print ''开始初始化表：''+@TableName'+@uniqueId+'+''....''
						declare @sqlInner11'+@uniqueId+' varchar(max) =''''
						set @sqlInner11'+@uniqueId+' = ''
							select * into '+@DBNameTo+'.dbo.[''+@TableName'+@uniqueId+'+''] from '+@DBNameFrom+'.dbo.[''+@TableName'+@uniqueId+'+'']
							print ''''初始化表结束：''+@TableName'+@uniqueId+'+''''''
							''
						exec(@sqlInner11'+@uniqueId+')
					end
			end
		--用游标去取下一条记录 
		fetch next from mycursor'+@uniqueId+' into @TableName'+@uniqueId+'
	end
	close mycursor'+@uniqueId+'
	deallocate mycursor'+@uniqueId+'
'
exec(@sql)
--脚本代码结束
print('同步数据库'+@DBNameFrom+'结束')
end