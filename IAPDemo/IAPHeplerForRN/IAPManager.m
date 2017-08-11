//
//  IAPManager.m
//  IAPDemo
//
//  Created by licheng ke on 2017/6/30.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

/*
  获取商品errorCode
   0 正常获取到商品 
   1 商品数组长度为0
   2 用户手机没开启内购
 */

/*
 交易 errorCode
0     交易已经提交
1     购买完成,向自己的服务器验证
2     交易失败
3     交易恢复购买商品
4     交易正在处理中

100    服务器验证成功
101    服务器验证失败
 */


#import "IAPManager.h"


@interface IAPManager ()
@property (nonatomic,strong) LCPurchaseHelper * helper;
@property (nonatomic,assign) BOOL hasListeners;
@end

@implementation IAPManager

RCT_EXPORT_MODULE();

-(instancetype)init{
  if (self = [super init]){
    self.helper = [LCPurchaseHelper share];
    [self registerNotification];
    // 为了避免JS中不确定的内存处理，还是用notification
    return self;
  }
  return nil;
}

RCT_EXPORT_METHOD
(getProductsWithIds:(NSArray *)productIDs)
{
  [self.helper getProductsWithIndentifies:productIDs];
}

RCT_EXPORT_METHOD
(goSystemSetting)
{
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

//选择商品触发购买
RCT_EXPORT_METHOD
(chooseProducts:(NSString *)productID
               userID:(NSString *)userID
                count:(NSNumber * __nonnull)count
              matchId:(NSString * )matchId
 )
{
  NSLog(@"用户选择商品：%@",productID);
  SKProduct * p = [self getProductWithID:productID];
  if (p) {
    [self.helper purchaseWithProduct:p andUserId:userID andCount:[count integerValue] matchId:matchId];
  }
  else {
    NSLog(@"RN传过来的商品在原生的商品列表中未找到");
  }
}

//恢复orderId 购买
RCT_EXPORT_METHOD
(continuePurchaseProducts:(NSString *)productID
 userID:(NSString *)userID
 count:(NSNumber * __nonnull)count
matchId:(NSString * )matchId
 )
{
  NSLog(@"用户选择商品：%@",productID);
  SKProduct * p = [self getProductWithID:productID];
  if (p) {
    [self.helper purchaseWithProduct:p andUserId:userID andCount:[count integerValue] matchId:matchId];
  }
  else {
    NSLog(@"RN传过来的商品在原生的商品列表中未找到");
  }
}

//根据穿过来的ID得到SKProduct
-(SKProduct *)getProductWithID:(NSString *)productID
{
  for (SKProduct * p in self.helper.products) {
    if ([p.productIdentifier isEqualToString:productID]) {
      return p;
    }
  }
  return nil;
}


#pragma mark - notification && event

-(void)startObserving {
  self.hasListeners = YES;
}

-(void)stopObserving {
  self.hasListeners = NO;
}

-(void)registerNotification{
  [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(retrieveProducts:) name:LCPurchaseProductsRetrievedNotification object:nil];
  [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(purchaseResult:) name:LCPurchaseProductsResult object:nil];

}

-(void)dealloc{
  [self unRegisterNotification];
}

- (void)unRegisterNotification{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)retrieveProducts:(NSNotification *)notification{
  NSLog(@"%s...\n info:%@",__FUNCTION__,notification.userInfo);
  NSArray * products = notification.userInfo[@"products"];
  NSNumber * errorCode = notification.userInfo[@"errorCode"];
  NSArray * convertedProducts = [IAPManager convertProductsToDic:products];
  if (self.hasListeners)
  [self sendEventWithName:RNEventReceivedProducts body:@{@"errorCode":errorCode,
                                                         @"products":convertedProducts}];
}

-(void)purchaseResult:(NSNotification *)notification{
  NSLog(@"%s...\n info:%@",__FUNCTION__,notification.userInfo);
  SKPaymentTransaction * transcation = notification.userInfo[@"transaction"]
  ;
  NSNumber * errorCode = notification.userInfo[@"errorCode"];
  NSString * description = notification.userInfo[@"description"];
  if (self.hasListeners)
  [self sendEventWithName:RNEventPurchaseResult
                     body:@{@"errorCode":errorCode,
                            @"description":description,
                            @"transactionID":transcation.transactionIdentifier ?: @""
                                                      }];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[RNEventReceivedProducts,RNEventPurchaseResult];
}

+(NSArray *)convertProductsToDic:(NSArray *)products
{
  NSMutableArray * container = [NSMutableArray array];
  for (SKProduct * p in products) {
    NSDictionary * dict = @{
                            @"pID" : p.productIdentifier ?:@"",
                            @"pPrice" : [NSString stringWithFormat:@"%@",p.price] ?:@"",
                            @"pTitle" : p.localizedTitle ?:@"",
                            @"pDescription" : p.localizedDescription ?:@"",
                            @"pLocalPrice" : [p.priceLocale objectForKey:NSLocaleCurrencySymbol] ?:@""
                            };
    [container addObject:dict];
  }
  return [container copy];
}

#pragma mark - order

RCT_EXPORT_METHOD
(getUnFinishOrder:(RCTResponseSenderBlock)block)
{
  NSDictionary * orderInfo = @{@"matchId":@"-1",@"orderId":@"-1",@"productId":@"-1"};
  NSDictionary * savedOrderInfo = [[NSUserDefaults standardUserDefaults]objectForKey:LCOrderRecordKey];
  if (savedOrderInfo) {
    orderInfo = savedOrderInfo;
  }
  block(@[orderInfo]);
}



@end
