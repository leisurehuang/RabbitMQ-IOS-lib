//
//  RabbitMQTViewController.m
//  RabbitMQT
//
//  Created by leisure huang on 12-7-2.
//  leisure.huang34@gmail.com
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "RabbitMQTViewController.h"

#include <sys/time.h>
#define SUMMARY_EVERY_US 1000000

@interface RabbitMQTViewController ()

@end

@implementation RabbitMQTViewController

@synthesize consumerString;
@synthesize consumerBtn;
@synthesize activeView;
@synthesize consumerTextView;
@synthesize sendingTextFeild;

#warning please input your info there
//guest
// hostName
char const *hostname = "192.168.40.2";

// prot
int port = 5672;

// userName
char const *userName = "guest";

// password
char const *password = "guest";

// exchangeName
char const *exchange = "fanot";

char const *bindingkey = "hello";
char const *routingkey = "hello";

// queueName
char const *queue = "11111";

// must put here!!!
int sockfd;
amqp_connection_state_t conn;
amqp_bytes_t queuename;


#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];

    // do binding
    [self binding];
    
    // init the String
    NSString *tString = [[NSString alloc]init];
    self.consumerString = tString;
    [tString release];
    
    // hidden activeView
    self.activeView.hidden = YES;
}

- (void)viewDidUnload
{
    [self setConsumerTextView:nil];
    [self setSendingTextFeild:nil];
    [self setConsumerBtn:nil];
    [self setActiveView:nil];
    [super viewDidUnload];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


- (void)dealloc 
{
    // unbinding
    [self unbinding];
    
    [consumerString release];
    [consumerTextView release];
    [sendingTextFeild release];
    [consumerBtn release];
    [activeView release];
    [super dealloc];
}

#pragma mark - UNIX Method

uint64_t now_microseconds(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t) tv.tv_sec * 1000000 + (uint64_t) tv.tv_usec;
}

void microsleep(int usec)
{
    usleep(usec);
}

#pragma mark - RabbitMQ Method
- (void)binding
{ 
    // Opening socket
    conn = amqp_new_connection();
    sockfd = amqp_open_socket(hostname, port);
    
    // is the Service OK?
    if (sockfd < 0) {
        printf("connect is error!");
        self.consumerTextView.text = @"Connect Service is Error!";
        return;
    }
    
    // Logging in
    amqp_set_sockfd(conn, sockfd);
    amqp_login(conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN, userName, password);
    
    // Opening channel
    amqp_channel_open(conn, 1);
    amqp_get_rpc_reply(conn);
    
    // declare Exchange
    amqp_exchange_declare(conn, 1, amqp_cstring_bytes(exchange), amqp_cstring_bytes("fanout"),
                          0, 0, amqp_empty_table);
    
    // declare Queue
    amqp_queue_declare_ok_t *r = amqp_queue_declare(conn, 1, amqp_cstring_bytes(queue), 0, 0, 0, 1,amqp_empty_table);
    
    // Declaring queue
    queuename = amqp_bytes_malloc_dup(r->queue);
    if (queuename.bytes == NULL) {
        fprintf(stderr, "Out of memory while copying queue name");
        
    }
    
    // binding queue
    amqp_table_t amqp_empty_table;
    amqp_queue_bind(conn, 1,
                    queuename,
                    amqp_cstring_bytes(exchange),
                    amqp_cstring_bytes(bindingkey),
                    amqp_empty_table);
    
}

- (void)unbinding
{
    // unbinding
    amqp_queue_unbind(conn, 1,
                      queuename,
                      amqp_cstring_bytes(exchange),
                      amqp_cstring_bytes(bindingkey),
                      amqp_empty_table);
    
    // Closing channel
    amqp_channel_close(conn, 1, AMQP_REPLY_SUCCESS);
    
    // Closing connection
    amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
    
    //Ending connection
    amqp_destroy_connection(conn);
}

- (IBAction)sendingString:(id)sender
{
    if ([self.sendingTextFeild.text length] == 0) {
        return;
    }
    char const *messagebody = [self.sendingTextFeild.text UTF8String];
    self.sendingTextFeild.text = @"";
    
    amqp_get_rpc_reply(conn);
    {
        //"Publishing");
        amqp_basic_properties_t props;
        props._flags = AMQP_BASIC_CONTENT_TYPE_FLAG | AMQP_BASIC_DELIVERY_MODE_FLAG;
        props.content_type = amqp_cstring_bytes("text/plain");
        props.delivery_mode = 2; /* persistent delivery mode */
        
        amqp_basic_publish(conn,
                           1,
                           amqp_cstring_bytes(exchange),
                           amqp_cstring_bytes(routingkey),
                           0,
                           0,
                           NULL,
                           amqp_cstring_bytes(messagebody));
    }
}

- (IBAction)consumerString:(id)sender
{
    self.activeView.hidden = NO;
    [activeView startAnimating];
    self.consumerBtn.hidden = YES;
    
    // Consuming
    amqp_basic_consume(conn, 1,queuename, amqp_empty_bytes, 0, 1, 0, amqp_empty_table);
    amqp_get_rpc_reply(conn);
    
    // run in a dispatch async queue
    dispatch_queue_t concurrentQueue =
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(concurrentQueue, 
                   ^{
                       // run(conn);
                       printf("DEBUG:run consumer!\n");
                       
                       uint64_t start_time = now_microseconds();
                       int received = 0;
                       int previous_received = 0;
                       uint64_t previous_report_time = start_time;
                       uint64_t next_summary_time = start_time + SUMMARY_EVERY_US;
                       amqp_frame_t frame;
                       int result;
                       size_t body_received;
                       size_t body_target;
                       uint64_t now;
                       
                       printf("DEBUG:do while\n");
                       
                       while (1) 
                       {
                           now = now_microseconds();
                           if (now > next_summary_time) {
                               int countOverInterval = received - previous_received;
                               double intervalRate = countOverInterval / ((now - previous_report_time) / 1000000.0);
                               printf("DEBUG:%d ms: Received %d - %d since last report (%d Hz)\n",
                                      (int)(now - start_time) / 1000, received, countOverInterval, (int) intervalRate);
                               
                               previous_received = received;
                               previous_report_time = now;
                               next_summary_time += SUMMARY_EVERY_US;
                           }
                           
                           amqp_maybe_release_buffers(conn);
                           
                           result = amqp_simple_wait_frame(conn, &frame);
                           if (result < 0)
                               return;
                           
                           if (frame.frame_type != AMQP_FRAME_METHOD)
                               continue;
                           
                           if (frame.payload.method.id != AMQP_BASIC_DELIVER_METHOD)
                               continue;
                           
                           result = amqp_simple_wait_frame(conn, &frame);
                           if (result < 0)
                               return;
                           
                           if (frame.frame_type != AMQP_FRAME_HEADER) {
                               fprintf(stderr, "Expected header!");
                               abort();
                           }
                           
                           body_target = frame.payload.properties.body_size;
                           body_received = 0;
                           
                           while (body_received < body_target) {
                               result = amqp_simple_wait_frame(conn, &frame);
                               if (result < 0)
                                   return;
                               
                               if (frame.frame_type != AMQP_FRAME_BODY) {
                                   fprintf(stderr, "Expected body!");
                                   abort();
                               }
                               
                               body_received += frame.payload.body_fragment.len;
                               assert(body_received <= body_target);
                           }
                           
                           received++;
                           // receive message
                           NSString *tempString = [[NSString alloc] init];
                           printf("DEBUG:The message is:");
                           for(int i = 0; i<frame.payload.body_fragment.len; i++)
                           {
                               printf("%c",*((char*)frame.payload.body_fragment.bytes+i));
                               tempString = [tempString stringByAppendingFormat:@"%c",*((char*)frame.payload.body_fragment.bytes+i)];
                           }
                           printf("\n");
                           self.consumerString = [ self.consumerString stringByAppendingFormat:@"%@  ",tempString];   
                           [tempString release];
                           
                           // back to mainThread show info
                           [self performSelectorOnMainThread:@selector(reShow) withObject:nil waitUntilDone:YES];
                           
                       }
                       
                   });    
    
}

- (void)reShow
{
    if ([self.consumerString length] == 0) {
        return;
    }
    
    self.consumerTextView.text = self.consumerString;
}

@end
