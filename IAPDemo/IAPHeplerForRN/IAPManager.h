//
//  IAPManager.h
//  IAPDemo
//
//  Created by licheng ke on 2017/6/30.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RCTEventEmitter.h"
#import "LCPurchaseHelper.h"

NSString * const RNEventReceivedProducts = @"RNEventReceivedProducts";
NSString * const RNEventPurchaseResult = @"RNEventPurchaseResult";

@interface IAPManager : RCTEventEmitter<RCTBridgeModule>

@end
