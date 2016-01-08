//
//  TNLog.h
//  TNLog
//
//  Created by JasonJ on 15/6/10.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 操作类型
 */
typedef enum : NSUInteger
{
    OPERATION_START     = 1,   //启动
    OPERATION_END       = 2,   //退出
    OPERATION_LOGIN     = 5,   //登录toon
    OPERATION_KILL      = 6,   //杀死toon进程
} OPERATION_TYPE;

/**
 功能类型
 */
typedef enum : NSUInteger
{
    FUNCTION_TYPE_BASE  =1,    //基本功能
    FUNCTION_TYPE_PLUG  =2,    //插件
    FUNCTION_TYPE_APPLY =3,    //应用
} FUNCTION_TYPE;

/**
 业务入口分类
 */
typedef enum : NSUInteger {
    CATEGORY_TYPE_GROUP = 1,        // 1.	群组8宫格操作
    CATEGORY_TYPE_CARD,             // 2.	名片8宫格操作
    CATEGORY_TYPE_NOTIFY,           // 3.	查看通知操作
    CATEGORY_TYPE_CHAT_PARTNER,     // 4.	聊伴内容点击
    CATEGORY_TYPE_OTHER             // 5.   其他功能操作
} CATEGORY_TYPE;

/**
 十点有约类型
 */
typedef enum : NSUInteger
{
    OPERATION_TYPE_REGISTER =1,
    OPERATION_TYPE_ENTER    =2
} TEN_OPERATION_TYPE;

@interface TNLog : NSObject


/**
 *  log初始化函数，在系统启动时调用
 *
 *  @param userid     用户名片id
 *  @param ipAddress  ip网址+端口,区分环境(测试环境地址：datest.syswin.com,生产环境地址:da.syswin.com)
 *  @param devicesId  设备唯一标志符
 */
+ (void)logInitWithUserid:(NSString *)userid
                ipAddress:(NSString *)ipAddress
                devicesId:(NSString *)devicesId;


/**
 *  基本设备信息上传(新)
 *
 *  @param operationType 操作类型
 */
+(void)deviceInfoWithOperationType:(OPERATION_TYPE)operationType;


/**
 *  功能操作信息接口
 *
 *  @param feedId       名片id
 *  @param functionType 功能类型
 *  @param functionId   功能id
 *  @param bizData      业务数据
 *  @param optionalParameters  可选参数,方便业务扩展使用.目前可选参数为:业务入口分类
 */
+(void)functionLogWithFeedId:(NSString *)feedId
                functionType:(FUNCTION_TYPE)functionType
                  functionId:(NSString *)functionId
                     bizData:(NSString *)bizData
          optionalParameters:(NSDictionary*)optionalParameters;

/**
 *  MWAP操作信息接口
 *
 *  @param dictionary 参数字典
 */
+ (void)mwapLogWithParDictionary:(NSDictionary *)dictionary;


/**
 *  十点有约埋点上传功能操作日志(弃用)
 *
 *  @param tenOperationType  十点有约操作类型
 *  @param userId        用户ID
 *  @param cardId        名片ID
 *  @param functionId    功能ID
 *  @param functionType  功能类型
 */
+ (void)updateFunctionLogWithOperationType:(TEN_OPERATION_TYPE)tenOperationType
                                    userId:(NSString *)userId
                                    cardId:(NSString *)cardId
                                functionId:(NSString *)functionId
                              functionType:(FUNCTION_TYPE)functionType;

/**
 *  神回复埋点上传功能操作日志(弃用)
 *
 *  @param operationNum  神回复操作类型id
 *  @param userId        用户ID
 *  @param cardId        名片ID
 *  @param functionId    功能ID
 *  @param functionType  功能类型
 */
+ (void)updateGodReplyWithOperationNum:(NSUInteger)operationNum
                                userId:(NSString *)userId
                                cardId:(NSString *)cardId
                            functionId:(NSString *)functionId
                          functionType:(FUNCTION_TYPE)functionType;

/**
 *  基本设备信息上传(弃用)
 *
 *  @param operationType 操作类型
 *  @param isActivation  是否第一次启动
 *  @param currentUserId 当前用户id
 */
+(void)deviceInfoWithOperationType:(OPERATION_TYPE)operationType
                      isActivation:(BOOL)isActivation
                        withUserId:(NSString *)currentUserId;

@end
