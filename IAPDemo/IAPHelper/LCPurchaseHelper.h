//
//  LCPurchaseHelper.h
//  IAPDemo
//
//  Created by licheng ke on 2017/6/28.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface LCPurchaseHelper : NSObject
@property (nonatomic,strong) NSArray * products;
@property (nonatomic,strong) NSArray * validProducts;

+(instancetype)share;

//获取商品
-(void)getProductsWithIndentifies:(NSArray *)ids andProductsBack:(void(^)(NSArray<SKProduct *> *))callBack;

//购买商品
-(void)purchaseWithProduct:(SKProduct *)product
                 andUserId:(NSString *)userId
                  andCount:(NSInteger)count;

//Observer
-(void)startObserverIAP;
-(void)stopOberverIPA;

@end
