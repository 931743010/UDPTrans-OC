//
//  DeveiceDataModel.h
//  scss
//
//  Created by lifubing on 16/3/9.
//  Copyright © 2016年 wisersoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeveiceDataModel : NSObject
@property (nonatomic, strong)NSString *IPAdress;
@property (nonatomic, strong)NSString *UserName;
@property (nonatomic)long long imagetag;

-(id)initWithIP:(NSString *)IP withUserName:(NSString *)Name withTag:(long long)Tag;
@end

