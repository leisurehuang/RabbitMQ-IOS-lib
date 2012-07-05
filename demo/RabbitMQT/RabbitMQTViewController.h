//
//  RabbitMQTViewController.h
//  RabbitMQT
//
//  Created by leisure huang on 12-7-2.
//  leisure.huang34@gmail.com
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "amqp.h"

@interface RabbitMQTViewController : UIViewController
{
    NSString *consumerString;

}
@property (retain, nonatomic) IBOutlet UIActivityIndicatorView *activeView;
@property (retain, nonatomic) IBOutlet UITextView *consumerTextView;
@property (retain, nonatomic) IBOutlet UITextField *sendingTextFeild;
@property (retain, nonatomic) NSString *consumerString;
@property (retain, nonatomic) IBOutlet UIButton *consumerBtn;

// 进行交换机和队列的绑定
- (void)binding;

// 解除绑定
- (void)unbinding;

// 发送测试字符
- (IBAction)sendingString:(id)sender;

// 进行消费者接收
- (IBAction)consumerString:(id)sender;

@end
