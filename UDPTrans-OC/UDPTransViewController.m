//
//  LightTransViewController.m
//  scss
//
//  Created by lifubing on 16/3/10.
//  Copyright © 2016年 lifubing. All rights reserved.
//

#import "UDPTransViewController.h"
#import "AsyncUdpSocket.h"
#import "IPHelper.h"
#import "DeveiceDataModel.h"
#import "NetWorkHelper.h"

static CGFloat const animationDurationTime = 4.0;                // 一次雷达动画持续的时间
static CGFloat const disPlayLinkFrameInterval = 200;             // 雷达动画的频率
static int const timerInterval = 4;                              // 设备缓存数据清空时间间隔

@interface UDPTransViewController ()<AsyncUdpSocketDelegate>

@property (nonatomic, strong) AsyncUdpSocket *sendSocket;        // 发送广播
@property (nonatomic, strong) AsyncUdpSocket *reciveSocket;      // 接受数据
@property (nonatomic, strong) NSMutableArray *driverIPList;      // 存储设备信息
@property (nonatomic, strong) NSMutableArray *scanDeveiceIPList; // 缓存timer时间内扫描到的设备信息
@property (nonatomic, strong) NSTimer *timer;                    // 检测 设备消失
@property NSInteger deveiceTag;                                  //         记录连接过的设备数量   不能置零
                                                                 //         并且 标记 添加的视图
                                                                 //         视图的消除 是根据Tag值

@property (nonatomic, strong) CALayer *layer;                    //
@property (nonatomic, strong) CAAnimationGroup *animaTionGroup;  //动画
@property (nonatomic, strong) CADisplayLink *disPlayLink;        //

@property (weak, nonatomic) IBOutlet UIImageView *userOfMe;
@property (weak, nonatomic) IBOutlet UILabel *userName;
@property (weak, nonatomic) IBOutlet UILabel *wifiNameLabel;
@end

@implementation UDPTransViewController
@synthesize sendSocket,driverIPList,scanDeveiceIPList,deveiceTag;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    driverIPList = [[NSMutableArray alloc]init];
    scanDeveiceIPList = [[NSMutableArray alloc]init];
    deveiceTag = 0;
    
    _disPlayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(delayAnimation)];
    _disPlayLink.frameInterval = disPlayLinkFrameInterval;
    [_disPlayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil]; //监听是否触发home键挂起程序.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil]; //监听是否重新进入程序程序.

    [self initSocket];
    [self initUIView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidDisappear:YES];
    [self drawCircle];
    [self.view bringSubviewToFront:self.backButton];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(checkData:) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:YES];
    _disPlayLink.paused = YES;
    [_timer invalidate];
    _animaTionGroup = nil;
}

- (void)dealloc {
    NSLog(@"dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initSocket {
    _reciveSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    [_reciveSocket bindToPort:6789 error:nil];
    [_reciveSocket receiveWithTimeout:-1 tag:0];
    
    sendSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    [sendSocket enableBroadcast:TRUE error:nil];
    [sendSocket bindToPort:0 error:nil];
    [sendSocket joinMulticastGroup:@"255.255.255.255" error:nil];
}


#pragma mark NSNotification
-(void)applicationWillResignActive: (id)sender {
    //进入后台
    NSLog(@"进入后台");
    _disPlayLink.paused = YES;
    [_timer invalidate];
    [sendSocket close];
    [_reciveSocket close];
    [sendSocket close];
}

-(void)applicationDidBecomeActive: (id)sender {
    //返回前台
    NSLog(@"返回前台");
    [self initSocket];
    _disPlayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(delayAnimation)];
    _disPlayLink.frameInterval = disPlayLinkFrameInterval;
    [_disPlayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(checkData:) userInfo:nil repeats:YES];

}

#pragma mark - AsyncUdpSocketDelegate

/**
 *  接受到消息HOST发送端ip
 *
 */

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port{
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *IPAdress = [host componentsSeparatedByString:@"::ffff:"].lastObject;
    NSString *userName = [dataString componentsSeparatedByString:@"myname:"].lastObject;
    NSLog(@"收到 %s %ld %@ %d %@",__FUNCTION__,tag,host,port,dataString);
    if ([IPAdress isEqualToString:[IPHelper deviceIPAdress]]) {
        //过滤来自本机的消息
        //继续监听接收消息
        [_reciveSocket receiveWithTimeout:-1 tag:0];
        return YES;
    }
    
        //处理消息
    if ([dataString rangeOfString:@"发送"].location != NSNotFound) {
        // 包含指定数据
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:IPAdress message:@"收到消息" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        }];
        
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }

    if ([self.scanDeveiceIPList indexOfObject:IPAdress] == NSNotFound) {
        [self.scanDeveiceIPList addObject:IPAdress];
        // 缓存 timer 4s 时间 内扫描到的设备
    }
    
    for (DeveiceDataModel *each in driverIPList) {
        if ([each.IPAdress isEqualToString:IPAdress]) {
            //已经添加有设备信息了
            [_reciveSocket receiveWithTimeout:-1 tag:0];
            return YES;
        }
    }
    //新的设备信息
    deveiceTag++;
    DeveiceDataModel *deveice = [[DeveiceDataModel alloc] initWithIP:IPAdress withUserName:userName withTag:deveiceTag];
    [driverIPList addObject:deveice];
    [self addUserToViewWithUserName:deveice.UserName];
    
    //继续监听接收消息
    [_reciveSocket receiveWithTimeout:-1 tag:0];
    return YES;
}

//每3秒钟刷新一次设备数据
- (void)checkData: (id)sender {
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (DeveiceDataModel *each in driverIPList) {
        if ([self.scanDeveiceIPList indexOfObject:each.IPAdress] == NSNotFound) {
            NSLog(@"~~消失 的IP地址是：%@ ~~",each.IPAdress);
            [array addObject:each]; //存储到数组中，待删除
            
            for (UIView *eachView in self.view.subviews) {
                
                if ([eachView isKindOfClass:[UIImageView class]]) {
                    if (eachView.tag == each.imagetag) {
                        // 根据tag删除view
                        [eachView removeFromSuperview];
                    }
                }
                
                if ([eachView isKindOfClass:[UILabel class]]) {
                    if (eachView.tag == each.imagetag) {
                        [eachView removeFromSuperview];
                    }
                }
            }
        }
    }
    //删除消失设备的信息
    for (DeveiceDataModel *each in array) {
        [driverIPList removeObject:each];
    }
    
    [self.scanDeveiceIPList removeAllObjects];
}

-(void)discoverDevices {
    //发送消息 查找服务器
    
    NSString *str = [NSString stringWithFormat:@"My IP:%@ myname:%@",[IPHelper deviceIPAdress],[[UIDevice alloc] init].name];
    [sendSocket sendData:[str dataUsingEncoding:NSUTF8StringEncoding]
                toHost: @"255.255.255.255" port: 6789 withTimeout:-1 tag:1];
    [sendSocket receiveWithTimeout: -1 tag:1];
    NSLog(@"持续搜索中！！");
}

#pragma mark UI
- (void)initUIView {
    
    self.userName.text = [[UIDevice alloc] init].name;
    [self cheackWifiName];
    [self.backButton.layer setBorderWidth:0.6];                             //设置边框的宽度
    [self.backButton.layer setBorderColor:[UIColor whiteColor].CGColor];    //设置按钮的边框颜色
}

- (void)drawCircle {
    CGFloat xPoint = CGRectGetWidth([UIScreen mainScreen].bounds) / 2;
    CGFloat yPoint = self.userOfMe.center.y;
    CGFloat width = CGRectGetWidth([UIScreen mainScreen].bounds)  / 2;
    CGFloat height = CGRectGetWidth([UIScreen mainScreen].bounds) / 2;
    
    for (int i = 1; i < 5; i++) {
        
        CAShapeLayer *solidLine =  [CAShapeLayer layer];
        CGMutablePathRef solidPath =  CGPathCreateMutable();
        solidLine.lineWidth = 0.6f + 0.1f*i ;
        solidLine.strokeColor = [[UIColor grayColor] colorWithAlphaComponent:0.4+0.1*i].CGColor;
        
        solidLine.fillColor = [UIColor clearColor].CGColor;
        
        CGPathAddEllipseInRect(solidPath, nil,CGRectMake(xPoint - width / 2 * i,
                                                         yPoint - width / 2 * i,
                                                         width * i,
                                                         height * i ));
        solidLine.path = solidPath;
        CGPathRelease(solidPath);
        [self.view.layer addSublayer:solidLine];
    }
}


- (void)startAnimation
{
    CALayer *layer = [[CALayer alloc] init];
    layer.cornerRadius = [UIScreen mainScreen].bounds.size.width*2;
    layer.frame = CGRectMake(0, 0, layer.cornerRadius * 2, layer.cornerRadius * 2);
    layer.position = CGPointMake(self.view.layer.position.x, self.userOfMe.layer.position.y);
    
    layer.backgroundColor = [UIColor whiteColor].CGColor;
    [self.view.layer addSublayer:layer];
    
    CAMediaTimingFunction *defaultCurve = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    _animaTionGroup = [CAAnimationGroup animation];
    _animaTionGroup.delegate = self;
    _animaTionGroup.duration = animationDurationTime;
    _animaTionGroup.removedOnCompletion = YES;
    _animaTionGroup.timingFunction = defaultCurve;

    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale.xy"];
    scaleAnimation.fromValue = @0.0;
    scaleAnimation.toValue = @1.0;
    scaleAnimation.duration = animationDurationTime;
    
    CAKeyframeAnimation *opencityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opencityAnimation.duration = animationDurationTime;
    opencityAnimation.values = @[@0.8,@0.4,@0];
    opencityAnimation.keyTimes = @[@0,@0.5,@1];
    opencityAnimation.removedOnCompletion = YES;
    
    NSArray *animations = @[scaleAnimation,opencityAnimation];
    _animaTionGroup.animations = animations;
    [layer addAnimation:_animaTionGroup forKey:nil];
    [self performSelector:@selector(removeLayer:) withObject:layer afterDelay:3];
    
    [UIView animateWithDuration:animationDurationTime / 10
                     animations:^{
                         self.userOfMe.transform = CGAffineTransformMakeScale(1.2, 1.2);
                     }completion:^(BOOL finish){
                         [UIView animateWithDuration:animationDurationTime / 10
                                          animations:^{
                                              self.userOfMe.transform = CGAffineTransformMakeScale(1, 1);
                                              
                                          }completion:^(BOOL finish){
                                          }];
                     }];
    
}

- (void)removeLayer:(CALayer *)layer
{
    [layer removeFromSuperlayer];
    [self.view.layer removeAllAnimations];
}

- (void)delayAnimation
{
    [self startAnimation];
    [self discoverDevices];
    [self cheackWifiName];
}

- (void)addUserToViewWithUserName:(NSString *) username{
    UIImageView *newUser = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"userOfSelf.png"]];
    [newUser setTag:deveiceTag];
    [newUser sizeToFit];
    CGFloat xPoint = 160;
    CGFloat yPoint = 160+arc4random()%200;
    [newUser setFrame:CGRectMake(xPoint, yPoint, 50, 50)];
    
    UILabel *newUserName = [[UILabel alloc]initWithFrame:CGRectMake(xPoint, yPoint + newUser.frame.size.width, 120, 30)];
    newUserName.textColor = [UIColor whiteColor];
    [newUserName setFont:[UIFont systemFontOfSize:14]];
    [newUserName setTag:deveiceTag];
    newUserName.text = username;
    newUserName.center = CGPointMake(newUser.center.x, yPoint+newUser.frame.size.width+12);
    newUserName.textAlignment = NSTextAlignmentCenter;
    NSLog(@"added user");
    newUser.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(Tap:)];
    [newUser addGestureRecognizer:tap];
    UITapGestureRecognizer *nameTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(Tap:)];
    [newUserName addGestureRecognizer:nameTap];
    [self.view addSubview:newUser];
    [self.view addSubview:newUserName];
    
}

#pragma mark - getter

-(void)cheackWifiName {
    NSString *wifiName = [NetWorkHelper getWifiName];
    if (wifiName != nil) {
        self.wifiNameLabel.text = [NSString stringWithFormat:@"当前网络:%@",wifiName];
    }else {
        self.wifiNameLabel.text = [NSString stringWithFormat:@"当前网络非WIFI环境,请查看帮助"];
    }
}

#pragma mark  selector
-(void)Tap:(id)sender{
    
    UITapGestureRecognizer *singleTap = (UITapGestureRecognizer *)sender;
    for (DeveiceDataModel *each in driverIPList) {
        if (each.imagetag == singleTap.view.tag) {
            
            UIView *imageView = [UIView alloc];
            for (UIView *eachView in self.view.subviews) {
                
                if ([eachView isKindOfClass:[UIImageView class]]) {
                    if (eachView.tag == each.imagetag) {
                        // 根据tag删除view
                        imageView = eachView;
                    }
                }
            }

            [UIView animateWithDuration:0.3
                 animations:^{
                 imageView.transform = CGAffineTransformMakeScale(1.2, 1.2);
                     
                 }completion:^(BOOL finish){
                     [UIView animateWithDuration:0.3
                      animations:^{
                          imageView.transform = CGAffineTransformMakeScale(1, 1);
                          
                      }completion:^(BOOL finish){
                          
                          UIAlertController *alertController = [UIAlertController alertControllerWithTitle:each.IPAdress message:each.UserName preferredStyle:UIAlertControllerStyleAlert];
                          
                          UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
                          NSString *str = [NSString stringWithFormat:@"发送消息给:%@",each.IPAdress];
                          UIAlertAction *OkAction = [UIAlertAction actionWithTitle:str style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                              AsyncUdpSocket *sendToUser = [[AsyncUdpSocket alloc]initWithDelegate:self];        // 发送数据
                              if ([sendToUser sendData:[@"发送消息" dataUsingEncoding:NSUTF8StringEncoding] toHost:each.IPAdress port:6789 withTimeout:-1 tag:0]) {
                                  NSLog(@"发送成功");
                              }else {
                                  NSLog(@"发送失败");
                              }
                              
                          }];
                          
                          [alertController addAction:cancelAction];
                          [alertController addAction:OkAction];
                          [self presentViewController:alertController animated:YES completion:nil];
                      }];
                 }];
        }
    }
    
}

- (IBAction)back:(id)sender {
    
    NSLog(@" = = dismiss = = ");
    _disPlayLink.paused = YES;
    [_disPlayLink invalidate];
    _disPlayLink = nil;
    
    [_timer invalidate];
    _timer = nil;
    
    [sendSocket close];
    sendSocket = nil;
    
    [_reciveSocket close];
    _reciveSocket = nil;
    
    [self.scanDeveiceIPList removeAllObjects];
    self.scanDeveiceIPList = nil;
    
    [driverIPList removeAllObjects];
    driverIPList = nil;
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)help:(id)sender {

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"项目需要做一些简单配置 \n比如: ARC与非ARC混编 swift与OC混编\n 方法很容易搜索到也可以到我简书文章中查看，有什么问题欢迎联系我\n" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        
    }];
    
    UIAlertAction *OkAction = [UIAlertAction actionWithTitle:@"前往我的简书" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        NSURL* url = [[ NSURL alloc ] initWithString :@"http://www.jianshu.com/users/e78a977ccaeb/"];
        [[UIApplication sharedApplication ] openURL: url];
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:OkAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}


@end
