//
//  ViewController.m
//  UDPTrans-OC
//
//  Created by lifubing on 16/3/10.
//  Copyright © 2016年 lifubing. All rights reserved.
//

#import "ViewController.h"
#import "UDPTransViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *buton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 40)];
    buton.center = CGPointMake(self.view.center.x, [UIScreen mainScreen].bounds.size.height * 4 / 5);
    [buton setTitle:@"start" forState:UIControlStateNormal];
    [buton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [buton addTarget:self action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:buton];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)open:(id)sender{
    UDPTransViewController *transVC = [[UDPTransViewController alloc] init];
    [self presentViewController:transVC animated:YES completion:nil];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)myWeibo:(id)sender {
    NSURL* url = [[ NSURL alloc ] initWithString :@"http://weibo.com/lfbWb"];
    [[UIApplication sharedApplication ] openURL: url];
}

@end
