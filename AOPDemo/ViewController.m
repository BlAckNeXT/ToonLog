//
//  ViewController.m
//  AOPDemo
//
//  Created by JasonJ on 15/6/16.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>

#define kDocumentsDirectory [NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define kLogDirectory [kDocumentsDirectory stringByAppendingString:@"/log/"]

@interface ViewController ()
{
    NSString *fileName;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
       
    [self testAOP];
    
    fileName =  @"TNLog_14_2015-06-18.txt";
    
}


- (IBAction)buttonOneClicked:(id)sender {
    [self showText];
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer             = [AFHTTPResponseSerializer serializer];
    manager.requestSerializer              = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"application/x-www-form-urlencoded",@"text/plain",@"application/json",nil];
    [manager POST:@"http://172.31.65.23/strategy/ios/logstrategy.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
//        NSString *resStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
//        NSLog(@"%@",responseObject);
//        NSString *resStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];

        NSDictionary *resDict = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        
        NSLog(@"%@",resDict);

        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSLog(@"error = %@",error);
    }];
    

}




- (IBAction)buttonTwoClicked:(id)sender {
    [self showText];
    

}

- (IBAction)secondVCButtonClicked:(id)sender {
    [self showText];
}

- (void)showText
{
    // 通过指定的路径读取文本内容
    NSString *logStr = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@%@",kLogDirectory,fileName] encoding:NSUTF8StringEncoding error:nil];
    _showTextView.text = logStr;
    [_showTextView scrollRectToVisible:CGRectMake(0, _showTextView.contentSize.height, _showTextView.contentSize.width, 10) animated:YES];
}


- (void)testAOP
{
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
