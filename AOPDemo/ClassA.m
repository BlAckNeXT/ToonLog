//
//  ClassA.m
//  AOPDemo
//
//  Created by JasonJ on 15/6/19.
//  Copyright (c) 2015年 Sysw1n. All rights reserved.
//

#import "ClassA.h"

@interface ClassA ()

@end

@implementation ClassA

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self funaa];
    
//    [self funab];
}

- (void)funaa{
    for (int a = 0; a < 100; a ++) {
        NSLog(@"%d",a);
    }
}

- (void)funab{
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
