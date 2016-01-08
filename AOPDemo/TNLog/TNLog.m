//
//  TNLog.m
//  TNLog
//
//  Created by JasonJ on 15/6/10.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import "TNLog.h"
#import <UIKit/UIKit.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import <zipzap.h>
//#import <minizip/minizip.h>
#import <AFNetworking.h>
#import <AdSupport/AdSupport.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CommonCrypto/CommonDigest.h>
#import <JSONKit/JSONKit.h>

//日志等级
typedef enum
{
    LOG_LEVEL_NONE      = 0,  //None
    LOG_LEVEL_DEBUG     = 1,  //Debug
    LOG_LEVEL_INFO      = 2,  //Info
    LOG_LEVEL_WARNING   = 3,  //Warning
    LOG_LEVEL_ERR       = 4,  //Error
} TNLogLevel;

//消息类型
typedef enum
{
    MESSAGE_SINGLE      = 1,   //单聊
    MESSAGE_GROUP       = 2,   //群聊
    MESSAGE_NOTICE      = 3,   //通知
} MESSAGE_TYPE;

//内容类型
typedef enum
{
    CONTENT_TEXT        = 1,   //文字
    CONTENT_IMAGE       = 2,   //图片
    CONTENT_LOCATION    = 3,   //位置
    CONTENT_VOICE       = 4,   //语音
    CONTENT_CARD        = 5,   //名片
    CONTENT_OTHER       = 99,  //其他
} CONTENT_TYPE;


#define kDocumentsDirectory [NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define kLogDirectory [kDocumentsDirectory stringByAppendingString:@"/log/"]
#define kAdid [TNLog uuid]
#define kFileNamePrefix [dateFormatter stringFromDate:[NSDate date]]
#define kFileName [NSString stringWithFormat:@"%@_02_%@_%@.toon",kAdid,fileNamePrefix,fileNumber]
#define kIMFileName [NSString stringWithFormat:@"%@_01_%@_%@.toon",kAdid,fileNamePrefix,IMFileNumber]
#define kFilePath [kLogDirectory stringByAppendingPathComponent:fileName]
#define kSpace @"\001"


#define kSaveDeviceInfo [NSString stringWithFormat:@"%@/datainterDevice/deviceServlet/saveDeviceInfo",[TNLog getIp]]

#define kUpdateFunctionLog [NSString stringWithFormat:@"%@/dataInterOper/operServlet/saveOperInfo",[TNLog getIp]]

#define kUpdateMWapDate [NSString stringWithFormat:@"%@/collectionWebLog/saveMwapInfo",[TNLog getIp]]

#define kUpdateLogZip @"http://da.syswin.com/collectionLogFile/fileUploadServlet/upload"


#define kAuchCode @"701393e7e636383948bbc6a45419cd86"
#define kAppKey @"1c9fc9ac4d8dacce014d8dad55a30103"

#define kUserIdKey @"TNLogUserId"
#define kIpAddressKey @"TNLogIpAddress"
#define kAppIsFirstLaunch @"TNLogAppIsFirstLaunch"
#define kStartFlag @"TNLogStartFlag"
#define kDeviceNumber @"TNLogDeviceNumber"

#ifdef DEBUG
//Debug默认记录的日志等级为LogLevelD。
static TNLogLevel LogLevel = LOG_LEVEL_DEBUG;
#else
//正常模式默认记录的日志等级为LogLevelI。
static TNLogLevel LogLevel = LOG_LEVEL_INFO;
#endif

// 打印队列
static dispatch_once_t logQueueCreatOnce;
static dispatch_queue_t k_operationQueue;

static NSString *logFilePath = nil;
static NSString *logDic      = nil;
static NSString *crashDic    = nil;
static NSString *userId      = nil;
static NSString *IMFilePath  = nil;
static NSString *fileNumber  = nil;
static NSString *IMFileNumber= nil;
static NSString *ip          = nil;
static NSString *startFlag   = nil;
static NSString *deviceNumber   = nil;


@implementation TNLog

/**
 *  log初始化函数，在系统启动时调用
 *
 *  @param userid     用户名片id
 *  @param ipAddress  ip网址,区分环境(测试环境地址：datest.syswin.com,生产环境地址:da.syswin.com)
 *  @param devicesId  设备唯一标志符
 */
+ (void)logInitWithUserid:(NSString *)userid
                ipAddress:(NSString *)ipAddress
                devicesId:(NSString *)devicesId
{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    if (userid) {
        userId = userid;
        [userDefault setValue:userId forKey:kUserIdKey];
    }else{
        userId = @"";
        [userDefault setValue:@"" forKey:kUserIdKey];
    }
    
    if (ipAddress) {
        ip = ipAddress;
        [userDefault setValue:ip forKey:kIpAddressKey];
    }
    
    if (devicesId) {
        deviceNumber = devicesId;
        [userDefault setValue:deviceNumber forKey:kDeviceNumber];
    }
    [userDefault synchronize];
}


/**
 *  设置要记录的log级别
 *
 *  @param level level 要设置的log级别
 */
+ (void)setLogLevel:(TNLogLevel)level
{
    LogLevel = level;
}


/**
 *  log日志信息等级前缀
 *
 *  @param logLevel 设置的log级别
 */
+ (NSString*)TNStringFromLogLevel:(TNLogLevel)logLevel
{
    switch (logLevel)
    {
        case LOG_LEVEL_NONE     :return @"NONE";
        case LOG_LEVEL_DEBUG    :return @"DEBUG";
        case LOG_LEVEL_INFO     :return @"INFO";
        case LOG_LEVEL_WARNING  :return @"WARNING";
        case LOG_LEVEL_ERR      :return @"ERROR";
    }
    return @"";
}


/**
 *  记录系统crash的Log函数
 *
 *  @param exception 系统异常
 */
+ (void)logCrash:(NSException*)exception
{
    if (exception == nil)
    {
        return;
    }
    

    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);

    
    if (!crashDic) {
        crashDic = kLogDirectory;
    }
    
    NSString *fileName = [NSString stringWithFormat:@"CRASH_%@_%@.log", userId,[[TNLog nowBeijingTime] description]];
    NSString *filePath = [crashDic stringByAppendingString:fileName];
    NSString *content  = [[NSString stringWithFormat:@"CRASH: %@\n", exception] stringByAppendingString:[NSString stringWithFormat:@"Stack Trace: %@\n", [exception callStackSymbols]]];
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *languages       = [defaults objectForKey:@"AppleLanguages"];
    NSString *phoneLanguage  = [languages objectAtIndex:0];
    
    content = [content stringByAppendingString:[NSString stringWithFormat:@"iPhone:%@  iOS Version:%@ Language:%@",[TNLog platformString], [[UIDevice currentDevice] systemVersion],phoneLanguage]];
    NSError *error = nil;
    [content writeToFile:filePath
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:&error];
    
    if (error) {
#if DEBUG
        NSLog(@"error is %@",error);
#endif
//        [TNLog logLevel:LOG_LEVEL_ERR LogInfo:@"CRASH LOG CREAT ERR INFO IS %@",error];
        
    }
}

/**
 *  log记录函数
 *
 *  @param level  log所属的等级
 *  @param format 具体记录log的格式以及内容
 */
+ (void)logLevel:(TNLogLevel)level LogInfo:(NSString *)logInfo
{
    dispatch_async(k_operationQueue, ^{
        
        if (level >= LogLevel) {
            NSString *log        = [[TNLog TNLogFormatPrefix:level] stringByAppendingString:logInfo];
            NSString *contentStr = log;
            NSString *contentN   = [contentStr stringByAppendingString:@"\n"];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString *content    = [NSString stringWithFormat:@"%@ %@", [dateFormatter stringFromDate:[TNLog nowBeijingTime]], contentN];
            // 拼接文本到文件里
            NSFileHandle *file   = [NSFileHandle fileHandleForUpdatingAtPath:logFilePath];
            [file seekToEndOfFile];
            [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            [file closeFile];

            NSLog(@"%@", content);

        }
        
    });
    
}


+ (void)IMLogInit
{
    if (!IMFilePath){
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:kLogDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:kLogDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        logDic   = kLogDirectory;
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        dateFormatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"GMT+0000"];
        NSString *fileNamePrefix = kFileNamePrefix;
//        NSInteger fileNumber  = 1;
        NSTimeInterval operationTime   = [[NSDate date] timeIntervalSince1970] * 1000;
        IMFileNumber = [NSString stringWithFormat:@"%.0f",operationTime];
        NSString *fileName       = kIMFileName;
        NSString *filePath       = kFilePath;
        
        IMFilePath  = filePath;
        NSLog(@"LogPath: %@", IMFilePath);

        // 如果不存在,创建文件
        if (![[NSFileManager defaultManager] fileExistsAtPath:IMFilePath]) {
             [[NSFileManager defaultManager] createFileAtPath:IMFilePath
                                                     contents:nil
                                                   attributes:nil];
            
        }
        
        dispatch_once(&logQueueCreatOnce, ^{
            k_operationQueue =  dispatch_queue_create("com.syswin.app.operationqueue", DISPATCH_QUEUE_SERIAL);
        });
    }
}



/**
 *  IM消息信息
 *
 *  @param logInfo        日志信息
 *  @param operationType  操作类型
 *  @param messageType    消息类型
 *  @param sendUserId     发送方用户ID
 *  @param sendCardId     发送方名片ID
 *  @param receiverUserId 接收方用户ID(如果是群聊，该字段为空)
 *  @param receiverCardId 接收方名片ID(如果是群聊，该字段为空)
 *  @param groupId        群ID(如果是单聊，该字段为空)
 *  @param contentType    内容类型
 */
+ (void)IMLogWithLogInfo:(NSString *)logInfo
           operationType:(OPERATION_TYPE)operationType
             MessageType:(MESSAGE_TYPE)messageType
              SendUserId:(NSString *)sendUserId
              SendCardId:(NSString *)sendCardId
          ReceiverUserId:(NSString *)receiverUserId
          ReceiverCardId:(NSString *)receiverCardId
                 GroupId:(NSString *)groupId
             ContentType:(CONTENT_TYPE)contentType
{
    dispatch_async(k_operationQueue, ^{
        
        [TNLog IMLogInit];
//        if (operationType == OPERATION_START) {
            NSString *operationId = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
            NSTimeInterval operationTime= [[NSDate date] timeIntervalSince1970];
            NSString *space = kSpace;
            NSString *log = [NSString stringWithFormat:@"%@%@%@%@%.0f%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@",operationId,space,[NSString stringWithFormat:@"%d",messageType],space,operationTime,[NSString stringWithFormat:@"%lu",(unsigned long)operationType],space,@"01",space,kAdid,space,sendUserId,space,sendCardId,space,receiverUserId,space,receiverCardId,space,groupId,space,[NSString stringWithFormat:@"%d",contentType]];
//            NSInteger fileNumber  = 1;
//            while ([TNLog fileSizeAtPath:IMFilePath]>2) {
//                fileNumber++;
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                dateFormatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"GMT+0000"];
                NSString *fileNamePrefix = kFileNamePrefix;
                NSString *fileName       = kIMFileName;
                NSString *filePath       = kFilePath;
                IMFilePath =  filePath;
                
//            }

            
            // 拼接文本到文件里
            NSFileHandle *file   = [NSFileHandle fileHandleForUpdatingAtPath:IMFilePath];
            [file seekToEndOfFile];
            [file writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
            [file closeFile];
            NSLog(@"%@", log);
//            }
    });
    
}



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
          optionalParameters:(NSDictionary*)optionalParameters

{
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,[NSString stringWithFormat:@"%.0f",t]]];
    
    if (!feedId) {
        feedId = @"";
    }
    if (!functionId) {
        functionId = @"";
    }
    if (!bizData) {
        bizData = @"";
    }
    
    NSString *bizCategoryStr;
    if (optionalParameters.allKeys.count == 0) {
        bizCategoryStr = @"";
    }else{
        bizCategoryStr = @"";
        if (optionalParameters[@"bizCategory"]) {
            bizCategoryStr = [NSString stringWithFormat:@"%@",optionalParameters[@"bizCategory"]];
        }
        if (optionalParameters[@"bc"]) {
            bizCategoryStr = [NSString stringWithFormat:@"%@",optionalParameters[@"bc"]];
        }
    }
    
    NSDictionary *parDic = @{@"sign":sign,
                             @"t":[NSString stringWithFormat:@"%.0f",t],
                             @"appKey":kAppKey,
                             @"data":@{
                                    @"sf":[TNLog getStartFlag],
                                    @"dn":[TNLog getDeviceNumber],
                                    @"ui":[TNLog getUserId],
                                    @"ci":feedId,
                                    @"ft":[NSString stringWithFormat:@"%lu",(unsigned long)functionType],
                                    @"fi":functionId,
                                    @"bc":bizCategoryStr,
                                    @"bd":bizData,
                                    @"dv":@"3"}
                             };
    NSString *parStr = [self dictionaryToJson:parDic];
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    NSDictionary *resDic = @{@"key":parStr};
    NSLog(@"实时上传功能操作日志上传参数 : %@",resDic);
    [manager POST:kUpdateFunctionLog parameters:resDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"实时上传功能操作日志responseString: %@",operation.responseString);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"实时上传功能操作日志error =%@",error);
    }];
    
}

/**
 *  MWAP操作信息接口
 *
 *  @param dictionary 参数字典
 */
+ (void)mwapLogWithParDictionary:(NSDictionary *)dictionary
{
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,[NSString stringWithFormat:@"%.0f",t]]];
    
    NSString *feedId = @"";
    NSString *cookie = @"";
    NSString *appPlugId = @"";
    NSString *appPlugVersion = @"";
    NSString *referrer = @"";
    NSString *url = @"";
    NSString *title = @"";
    NSString *operation=@"";
    if (dictionary[@"cardID"]) {
        feedId = [NSString stringWithFormat:@"%@",dictionary[@"cardID"]];
    }
    if (dictionary[@"cookie"]) {
        cookie = [NSString stringWithFormat:@"%@",dictionary[@"cookie"]];
    }
    if (dictionary[@"appPlugId"]) {
        appPlugId = [NSString stringWithFormat:@"%@",dictionary[@"appPlugId"]];
    }
    if (dictionary[@"appPlugVersion"]) {
        appPlugVersion = [NSString stringWithFormat:@"%@",dictionary[@"appPlugVersion"]];
    }
    if (dictionary[@"referrer"]) {
        referrer = [NSString stringWithFormat:@"%@",dictionary[@"referrer"]];
    }
    if (dictionary[@"url"]) {
        url = [NSString stringWithFormat:@"%@",dictionary[@"url"]];
    }
    if (dictionary[@"title"]) {
        title = [NSString stringWithFormat:@"%@",dictionary[@"title"]];
    }
    if (dictionary[@"operation"]) {
        operation = [NSString stringWithFormat:@"%@",dictionary[@"operation"]];
    }
    
    NSDictionary *parDic = @{@"sign":sign,
                             @"t":[NSString stringWithFormat:@"%.0f",t],
                             @"appKey":kAppKey,
                             @"data":@{
                                     @"sf":[TNLog getStartFlag],
                                     @"dn":[TNLog getDeviceNumber],
                                     @"ui":[TNLog getUserId],
                                     @"ci":feedId,
                                     @"ck":cookie,
                                     @"ai":appPlugId,
                                     @"av":appPlugVersion,
                                     @"rf":referrer,
                                     @"url":url,
                                     @"ti":title,
                                     @"ot":operation,
                                     @"dv":@"2"}
                             };

    NSString *parStr = [self dictionaryToJson:parDic];
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    NSDictionary *resDic = @{@"key":parStr};
    NSLog(@"MWAP操作信息接口 : %@",resDic);
    [manager POST:kUpdateMWapDate parameters:resDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"MWAP操作信息接口responseString: %@",operation.responseString);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"MWAP操作信息接口error =%@",error);
    }];

    
}


/**
 *  十点有约埋点上传功能操作日志
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
                              functionType:(FUNCTION_TYPE)functionType

{
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,[NSString stringWithFormat:@"%.0f",t]]];
    
    NSString *operationId = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    
    if (!userId) {
        userId = @"0";
    }
    if (!cardId) {
        cardId = @"0";
    }
    if (!functionId) {
        functionId = @"0";
    }
    NSDictionary *parDic = @{@"sign":sign,
                             @"t":[NSString stringWithFormat:@"%.0f",t],
                             @"appKey":kAppKey,
                             @"data":@{@"operationId":operationId,
                                       @"operationTime":[NSString stringWithFormat:@"%.0f",t*1000],
                                       @"operationType":[NSString stringWithFormat:@"%lu",(unsigned long)tenOperationType],
                                       @"logType":@"02",
                                       @"devicesNumber":kAdid,
                                       @"userId":userId,
                                       @"cardId":cardId,
                                       @"functionType":[NSString stringWithFormat:@"%lu",(unsigned long)functionType],
                                       @"functionId":functionId,
                                       @"dataVersion":@"2"}
                             };
    NSString *parStr = [self dictionaryToJson:parDic];
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    NSDictionary *resDic = @{@"key":parStr};
    NSLog(@"实时上传功能操作日志上传参数 : %@",resDic);
    [manager POST:kUpdateFunctionLog parameters:resDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"实时上传功能操作日志responseString: %@",operation.responseString);
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"实时上传功能操作日志error =%@",error);
        //        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
        //                                       @"error_msg" :error}
        //                               error:errorblock];
        
    }];
    
}


/**
 *  神回复埋点上传功能操作日志
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
                          functionType:(FUNCTION_TYPE)functionType

{
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,[NSString stringWithFormat:@"%.0f",t]]];
    
//    NSString *operationId = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    
    if (!userId) {
        userId = @"0";
    }
    if (!cardId) {
        cardId = @"0";
    }
    if (!functionId) {
        functionId = @"0";
    }
    NSDictionary *parDic = @{@"sign":sign,
                             @"t":[NSString stringWithFormat:@"%.0f",t],
                             @"appKey":kAppKey,
                             @"data":@{@"operationId":kAdid,
                                       @"operationTime":[NSString stringWithFormat:@"%.0f",t*1000],
                                       @"operationType":[NSString stringWithFormat:@"%lu",(unsigned long)operationNum],
                                       @"logType":@"02",
                                       @"devicesNumber":kAdid,
                                       @"userId":userId,
                                       @"cardId":cardId,
                                       @"functionType":[NSString stringWithFormat:@"%lu",(unsigned long)functionType],
                                       @"functionId":functionId,
                                       @"dataVersion":@"2"}
                             };
    NSString *parStr = [self dictionaryToJson:parDic];
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    NSDictionary *resDic = @{@"key":parStr};
    NSLog(@"实时上传功能操作日志上传参数 : %@",resDic);
    [manager POST:kUpdateFunctionLog parameters:resDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"实时上传功能操作日志responseString: %@",operation.responseString);
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"实时上传功能操作日志error =%@",error);
        //        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
        //                                       @"error_msg" :error}
        //                               error:errorblock];
        
    }];
    
}


/**
 *  基本设备信息上传
 *
 *  @param operationType 操作类型
 */
+(void)deviceInfoWithOperationType:(OPERATION_TYPE)operationType
{
    // 通过本地标志符判断是否是第一次启动
    BOOL isActivation = NO;
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    if ([[userDefault valueForKey:kAppIsFirstLaunch] isEqualToString:@"no"]) {
        isActivation = NO;
    }else{
        [userDefault setValue:@"no" forKey:kAppIsFirstLaunch];
        [userDefault synchronize];
        isActivation = YES;
    }
    
    // 如果是启动toon的话,就需要生成staryFlag
    if (operationType == OPERATION_START) {
        startFlag = kAdid;
        [userDefault setValue:startFlag forKey:kStartFlag];
        [userDefault synchronize];
    }
    
    
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,[NSString stringWithFormat:@"%.0f",t]]];
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    // app版本
    NSString *app_Version = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *build_Version =[infoDictionary objectForKey:@"CFBundleVersion"];

    CGRect rect = [[UIScreen mainScreen] bounds];
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat width = rect.size.width * scale;
    CGFloat height = rect.size.height * scale;
    
    NSString *carrierName = [TNLog getCarrierName];
    if ([carrierName isEqualToString:@"中国移动"]) {
        carrierName= @"1";
    }else if ([carrierName isEqualToString:@"中国电信"]){
        carrierName= @"2";
    }else if ([carrierName isEqualToString:@"中国联通"]){
        carrierName= @"3";
    }else{
        carrierName= @"4"; // 无
    }
    
    NSString *resolution = [NSString stringWithFormat:@"%.0f*%.0f",height,width];
    NSDictionary *dic = @{@"ot":[NSString stringWithFormat:@"%lu",(unsigned long)operationType],
                          @"sf":[TNLog getStartFlag],
                          @"dn":[TNLog getDeviceNumber],
                          @"ui":[TNLog getUserId],
                          @"dc":[TNLog platform],
                          @"os":@"IOS",
                          @"ov":[[UIDevice alloc]init].systemVersion,
                          @"tv":app_Version,
                          @"bv":build_Version,
                          @"rs":resolution,
                          @"nw":[TNLog networkType],
                          @"op":carrierName,
                          @"ch":@"AppStore",
                          @"at":[NSString stringWithFormat:@"%d",isActivation],
                          @"dv":@"4"
                          };
    NSDictionary *parDic = @{@"sign":sign,
                             @"t":[NSString stringWithFormat:@"%.0f",t],
                             @"appKey":kAppKey,
                             @"data":dic
                             };
    
    NSString *parStr = [self dictionaryToJson:parDic];
    NSDictionary *resDic = @{@"key":parStr};
    NSLog(@"基本设备信息日志上传参数 : %@",resDic);
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    [manager POST:kSaveDeviceInfo parameters:resDic success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"基本设备信息日志上传responseString: %@",operation.responseString);
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"基本设备信息上传error =%@",error);
    }];
}

+(void)deviceInfoWithOperationType:(OPERATION_TYPE)operationType isActivation:(BOOL)isActivation withUserId:(NSString *)currentUserId
{
    [TNLog deviceInfoWithOperationType:operationType];
}

+ (AFHTTPRequestOperationManager *)AFManagerInit
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer             = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer              = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"application/x-www-form-urlencoded",@"text/plain",@"application/json",nil];
    manager.requestSerializer.timeoutInterval = 10.0f;
    
    return manager;
}



#pragma mark - Handle Log Methods
/**
 *  把log打包为.zip文件
 *
 *  @param logName log的文件全名
 */
+ (void)archiveLogWithLogName:(NSString *)logName
                        error:(void(^)(NSDictionary *errDict))errorblock
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,logName]]) {
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file is not exist!"} error:errorblock];
        return;
    }
    NSString *logNameExpeToon = [logName substringToIndex:logName.length-5];
    ZZArchive *newArchive = [[ZZArchive alloc] initWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.zip",kLogDirectory,logNameExpeToon]]
                                                   options:@{ZZOpenOptionsCreateIfMissingKey : @YES}
                                                     error:nil];
    // 通过指定的路径读取文本内容
    NSString *logStr = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@%@",kLogDirectory,logName] encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"%@",kLogDirectory);
    NSError *error = nil;
    [newArchive updateEntries:@[
                                [ZZArchiveEntry archiveEntryWithFileName:logName
                                                                compress:YES
                                                               dataBlock:^(NSError** error)
                                 {
                                     return [logStr dataUsingEncoding:NSUTF8StringEncoding];
                                 }]
                                ]
                        error:&error];
    if (error) {
        NSLog(@"archive log error, error = %@",error);
        [TNLog errorBlockWithErrDict:@{@"error_code":@"102",
                                       @"error_msg" :[NSString stringWithFormat:@"archive log error, error =%@",error]} error:errorblock];
    }
    
//    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,logName]]) {
//        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
//                                       @"error_msg" :@"file is not exist!"} error:errorblock];
//        return;
//    }
//    
//    ZipArchive *newArchive = [[ZipArchive alloc] init];
//    NSString *logNameExpeToon = [logName substringToIndex:logName.length-5];
//    
//    NSString *zipFile = [NSString stringWithFormat:@"%@%@.zip",kLogDirectory,logNameExpeToon];
//    BOOL ret = [newArchive CreateZipFile2:zipFile];
//    NSString *file = [NSString stringWithFormat:@"%@%@",kLogDirectory,logName];
//    ret = [newArchive addFileToZip:file newname:logName];
//    if(![newArchive CloseZipFile2] )
//    {
//        NSLog(@"archive log error, error = zipArchive ERROR");
//        [TNLog errorBlockWithErrDict:@{@"error_code":@"102",
//                                       @"error_msg" :@"archive log error",
//                                       } error:errorblock];
//    }
//
}

/**
 *  把.zip文件上传到服务器
 *
 *  @param zipName log.zip的文件全名
 */
+ (void)uploadLogWithZipName:(NSString *)zipName
                       error:(void(^)(NSDictionary *errDict))errorblock
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,zipName]]) {
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file is not exist!"} error:errorblock];
        return;
    }
    
    NSString *t = [NSString stringWithFormat:@"%.0f",[[NSDate date]timeIntervalSince1970]];
    NSString *sign = [TNLog md5:[NSString stringWithFormat:@"%@%@%@",kAppKey,kAuchCode,t]];
    NSDictionary *dic = @{@"sign":sign,
                          @"t":t,
                          @"appKey":kAppKey
                          };
    NSDictionary *parDict = @{@"key":[self dictionaryToJson:dic]
                              };
    
//    NSString *parStr = [parDict JSONString];
    NSLog(@"parDict = %@",parDict);
    AFHTTPRequestOperationManager *manager = [TNLog AFManagerInit];
    NSURL *filePath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@",kLogDirectory,zipName]];
    [manager POST:kUpdateLogZip parameters:parDict constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileURL:filePath name:@"zip" error:nil];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString    *result = [[NSString alloc] initWithData:responseObject  encoding:NSUTF8StringEncoding];
        NSLog(@"result =%@",result);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [TNLog errorBlockWithErrDict:@{@"error_code":@"103",
                                       @"error_msg" :[NSString stringWithFormat:@"%@",error]} error:errorblock];
    }];
}

/**
 *  根据文件名删除本地存的日志文件
 *
 *  @param fileName 要删除的文件全名
 */
+ (void)deleteLogWithFileName:(NSString *)fileName
                        error:(void(^)(NSDictionary *errDict))errorblock
{
    NSString *filePath = [NSString stringWithFormat:@"%@%@",kLogDirectory,fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath
                                                   error:&error];
        if (error) {
            NSLog(@"delete log error ,error = %@",error);
            [TNLog errorBlockWithErrDict:@{@"error_code":@"102",
                                           @"error_msg" :[NSString stringWithFormat:@"%@",error]}
                                   error:errorblock];
        }
    }else{
        NSLog(@"file path not exist! delete fail!");
        [TNLog errorBlockWithErrDict:@{@"error_code":@"101",
                                       @"error_msg" :@"file path not exist! delete fail!"}
                               error:errorblock];
    }

}

+ (NSString*)dictionaryToJson:(NSDictionary *)dic

{
    
    NSError *parseError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
}

/**
 *  发生错误时block回调函数
 *
 */
+ (void)errorBlockWithErrDict:(NSDictionary *)errDic
                        error:(void(^)(NSDictionary *errDict))error
{
    error(errDic);
}



#pragma mark - Device Info
/**
 *  获取当前时间
 */
+ (NSDate *)nowBeijingTime
{
    NSTimeZone *AA    = [NSTimeZone timeZoneWithAbbreviation:@"GMT+0000"];
    NSInteger seconds = [AA secondsFromGMTForDate: [NSDate date]];
    return [NSDate dateWithTimeInterval: seconds sinceDate: [NSDate date]];
}

/**
 *  获取机型信息
 */
+ (NSString *)platform
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

/**
 *  机型信息
 */
+ (NSString *)platformString
{
    NSString *platform = [TNLog platform];
    if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 2G (A1203)";
    if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G (A1241/A1324)";
    if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS (A1303/A1325)";
    if ([platform isEqualToString:@"iPhone3,1"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,2"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,3"]) return @"iPhone 4 (A1349)";
    if ([platform isEqualToString:@"iPhone4,1"]) return @"iPhone 4S (A1387/A1431)";
    if ([platform isEqualToString:@"iPhone5,1"]) return @"iPhone 5 (A1428)";
    if ([platform isEqualToString:@"iPhone5,2"]) return @"iPhone 5 (A1429/A1442)";
    if ([platform isEqualToString:@"iPhone5,3"]) return @"iPhone 5c (A1456/A1532)";
    if ([platform isEqualToString:@"iPhone5,4"]) return @"iPhone 5c (A1507/A1516/A1526/A1529)";
    if ([platform isEqualToString:@"iPhone6,1"]) return @"iPhone 5s (A1453/A1533)";
    if ([platform isEqualToString:@"iPhone6,2"]) return @"iPhone 5s (A1457/A1518/A1528/A1530)";
    if ([platform isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus (A1522/A1524)";
    if ([platform isEqualToString:@"iPhone7,2"]) return @"iPhone 6 (A1549/A1586)";
    
    if ([platform isEqualToString:@"iPod1,1"])   return @"iPod Touch 1G (A1213)";
    if ([platform isEqualToString:@"iPod2,1"])   return @"iPod Touch 2G (A1288)";
    if ([platform isEqualToString:@"iPod3,1"])   return @"iPod Touch 3G (A1318)";
    if ([platform isEqualToString:@"iPod4,1"])   return @"iPod Touch 4G (A1367)";
    if ([platform isEqualToString:@"iPod5,1"])   return @"iPod Touch 5G (A1421/A1509)";
    
    if ([platform isEqualToString:@"iPad1,1"])   return @"iPad 1G (A1219/A1337)";
    
    if ([platform isEqualToString:@"iPad2,1"])   return @"iPad 2 (A1395)";
    if ([platform isEqualToString:@"iPad2,2"])   return @"iPad 2 (A1396)";
    if ([platform isEqualToString:@"iPad2,3"])   return @"iPad 2 (A1397)";
    if ([platform isEqualToString:@"iPad2,4"])   return @"iPad 2 (A1395+New Chip)";
    if ([platform isEqualToString:@"iPad2,5"])   return @"iPad Mini 1G (A1432)";
    if ([platform isEqualToString:@"iPad2,6"])   return @"iPad Mini 1G (A1454)";
    if ([platform isEqualToString:@"iPad2,7"])   return @"iPad Mini 1G (A1455)";
    
    if ([platform isEqualToString:@"iPad3,1"])   return @"iPad 3 (A1416)";
    if ([platform isEqualToString:@"iPad3,2"])   return @"iPad 3 (A1403)";
    if ([platform isEqualToString:@"iPad3,3"])   return @"iPad 3 (A1430)";
    if ([platform isEqualToString:@"iPad3,4"])   return @"iPad 4 (A1458)";
    if ([platform isEqualToString:@"iPad3,5"])   return @"iPad 4 (A1459)";
    if ([platform isEqualToString:@"iPad3,6"])   return @"iPad 4 (A1460)";
    
    if ([platform isEqualToString:@"iPad4,1"])   return @"iPad Air (A1474)";
    if ([platform isEqualToString:@"iPad4,2"])   return @"iPad Air (A1475)";
    if ([platform isEqualToString:@"iPad4,3"])   return @"iPad Air (A1476)";
    if ([platform isEqualToString:@"iPad4,4"])   return @"iPad Mini 2G (A1489)";
    if ([platform isEqualToString:@"iPad4,5"])   return @"iPad Mini 2G (A1490)";
    if ([platform isEqualToString:@"iPad4,6"])   return @"iPad Mini 2G (A1491)";
    
    if ([platform isEqualToString:@"i386"])      return @"iPhone Simulator";
    if ([platform isEqualToString:@"x86_64"])    return @"iPhone Simulator";
    
    return platform;
}

/**
 *  获取网络类型
 *  @return 网络类型编号
 */
+ (NSString *)networkType
{
    NSArray *subviews = [[[[UIApplication sharedApplication] valueForKey:@"statusBar"] valueForKey:@"foregroundView"]subviews];
    NSNumber *dataNetworkItemView = nil;
    for (id subview in subviews) {
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
            dataNetworkItemView = subview;
            break;
        }
    }
    
    switch ([[dataNetworkItemView valueForKey:@"dataNetworkType"]integerValue]) {
        case 0:
            return @"4"; // 无网络 (因为无网络无法请求接口,所以服务器能收到的数据最差也是2g,默认为2g网)
            break;
            
        case 1:
            return @"4"; // 2G
            break;
            
        case 2:
            return @"3"; // 3G
            break;
            
        case 3:
            return @"2"; // 4G
            break;
            
        case 4:
            return @"2"; // LTE
            break;
            
        case 5:
            return @"1"; // Wifi
            break;
            
            
        default:
            return @"4"; // 无网络或未知
            break;
    }
    
    return @"0";
}


/**
 *  获取运营商名字
 *  @return 运营商名字
 */
+ (NSString *)getCarrierName
{
    CTTelephonyNetworkInfo *telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [telephonyInfo subscriberCellularProvider];
    NSString *currentCountry=[carrier carrierName];
    NSLog(@"[carrier isoCountryCode]==%@,[carrier allowsVOIP]=%d,[carrier mobileCountryCode=%@,[carrier mobileCountryCode]=%@,carrirerName = %@",[carrier isoCountryCode],[carrier allowsVOIP],[carrier mobileCountryCode],[carrier mobileNetworkCode],currentCountry);
    return currentCountry;
}


#pragma mark - Handle Data

/**
 *  给字符串MD5加密
 *
 *  @param str 需要MD5的字符串
 *  @return 加密后的字符串
 */
+ (NSString *)md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ]; 
}


/**
 *  log日志信息等级前缀
 *
 *  @param logLevel 设置的log级别
 */
+ (NSString*)TNLogFormatPrefix:(TNLogLevel)logLevel
{
    return [NSString stringWithFormat:@"[%@] ", [TNLog TNStringFromLogLevel:logLevel]];
}


/**
 *  指定路径的文件大小
 *
 *  @param filePath 文件路径
 *
 *  @return 返回文件大小
 */
+ (long long)fileSizeAtPath:(NSString*) filePath
{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize]/1024/1024;
    }
    return 0;
}


+ (NSString *)uuid
{
    CFUUIDRef puuid = CFUUIDCreate( nil );
    CFStringRef uuidString = CFUUIDCreateString( nil, puuid );
    NSString * result = (NSString *)CFBridgingRelease(CFStringCreateCopy( NULL, uuidString));
    CFRelease(puuid);
    CFRelease(uuidString);
    return result ;
}

+ (NSString *)getUserId
{
    if (!userId) {
        userId = [[NSUserDefaults standardUserDefaults] valueForKey:kUserIdKey];
        if (!userId || userId.length == 0) {
            userId = @"0";
        }
        return userId;
    }
    return userId;
}

+ (NSString *)getStartFlag
{
    if (!startFlag) {
        startFlag = [[NSUserDefaults standardUserDefaults] valueForKey:kStartFlag];
        if (!startFlag || startFlag.length == 0) {
            startFlag = kAdid;
        }
        return startFlag;
    }
    return startFlag;
}

+ (NSString *)getDeviceNumber
{
    if (!deviceNumber) {
        deviceNumber = [[NSUserDefaults standardUserDefaults] valueForKey:kDeviceNumber];
        if (!deviceNumber || deviceNumber.length == 0) {
            deviceNumber = @"";
        }
        return deviceNumber;
    }
    return deviceNumber;
}

+ (NSString *)getIp
{
    if (!ip) {
        ip = [[NSUserDefaults standardUserDefaults] valueForKey:kIpAddressKey];
        if (!ip || ip.length == 0) {
            ip = @"da.syswin.com";
        }
        return ip;
    }
    return ip;
}



@end
