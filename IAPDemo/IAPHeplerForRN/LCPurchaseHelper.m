//
//  LCPurchaseHelper.m
//  IAPDemo
//
//  Created by licheng ke on 2017/6/28.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

#import "LCPurchaseHelper.h"

NSString * const LCPurchaseProductsRetrievedNotification = @"LCPurchaseProductsRetrievedNotification";

NSString * const LCPurchaseProductsResult = @"LCPurchaseProductsResult";
NSString * TestReciptURL = @"自己的服务器地址/ 测试也可以在本地验证";

static LCPurchaseHelper * helper = nil;

@interface LCPurchaseHelper ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

@property (nonatomic,strong) SKProductsRequest * pRequest;

@end

@implementation LCPurchaseHelper

+(instancetype)share{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[LCPurchaseHelper alloc]init];
    });
    return helper;
}

-(NSArray *)products {
    if (!_products){
        _products = @[];
    }
    return _products;
}

-(void)getProductsWithIndentifies:(NSArray *)ids
{
    if ([SKPaymentQueue canMakePayments]){
        if (ids.count) {
            NSSet * idSet = [NSSet setWithArray:ids];
            SKProductsRequest * pRequest = [[SKProductsRequest alloc]initWithProductIdentifiers:idSet];
            self.pRequest = pRequest;
            pRequest.delegate = self;
            [pRequest start];
        }
        else {
            NSLog(@"No Products Indentifies");
        }
    }
    else {
        NSLog(@"用户未允许付费");
    }
}

- (NSArray *)validProducts:(NSArray *)products andInvalidIds:(NSArray *)ids{
    if (ids.count == 0) return products;
    NSMutableArray * container = [NSMutableArray array];
    for (SKProduct * p in products) {
        BOOL isValided = true;
        for (NSString * indentify in ids){
            if ([indentify isEqualToString:p.productIdentifier]){
                isValided = false;
                break;
            }
        }
        if (isValided) {
            [container addObject:p];
        }
    }
    return container.copy;
}



#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    
    self.products = response.products;

    NSLog(@"invalidProductIdentifiers:%@",response.invalidProductIdentifiers);
    self.validProducts = [self validProducts:response.products andInvalidIds:response.invalidProductIdentifiers];
    
    for (SKProduct * p in self.products) {
        NSLog(@"...>>>  \n");
        NSLog(@"localizedTitle %@", [p localizedTitle]);
        NSLog(@"localizedDescription %@", [p localizedDescription]);
        NSLog(@"price %@", [p price]);
        NSLog(@"%@", [p.priceLocale objectForKey:NSLocaleCurrencySymbol]);
        NSLog(@"%@", [p.priceLocale objectForKey:NSLocaleCurrencyCode]);
        NSLog(@"%@", [p productIdentifier]);
    }

      [[NSNotificationCenter defaultCenter]postNotificationName:LCPurchaseProductsRetrievedNotification object:nil userInfo:@{@"products":[self.products copy]}];
}


#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
  NSLog(@"本地有%@个transactions",@([transactions count]));
    for (SKPaymentTransaction *transaction in transactions) {
      NSString * description = @"";
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:{
                description = @"交易已经提交";
              [self purchaseHandleErrorCode:SKPaymentTransactionStatePurchasing transcation:transaction description:description];
                break;
            }
            case SKPaymentTransactionStateDeferred: {
                description = @"交易正在处理中";
               [self purchaseHandleErrorCode:SKPaymentTransactionStateDeferred transcation:transaction description:description];
                break;
            }
            case SKPaymentTransactionStateRestored:{
                description = @"交易恢复购买商品";
               [self purchaseHandleErrorCode:SKPaymentTransactionStateRestored transcation:transaction description:description];
                break;
            }
            case SKPaymentTransactionStateFailed: {

                description = [NSString stringWithFormat:@"交易失败 : %@",
                               transaction.error.localizedDescription];
               [self purchaseHandleErrorCode:SKPaymentTransactionStateFailed transcation:transaction description:description];
            }
                break;
            case SKPaymentTransactionStatePurchased:{
                description = @"购买完成,向自己的服务器验证";
                [self purchaseResultHandleWithTransaction:transaction success:YES];
                break;
            }
            default:{
                description = @"未知情况";
                break;
            }
        }
        NSLog(@"%@",description);
    }
}

#pragma mark - ObserverManage
-(void)startObserverIAP{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

-(void)stopOberverIPA{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - Purchase
-(void)purchaseWithProduct:(SKProduct *)product
                 andUserId:(NSString *)userId
                  andCount:(NSInteger)count
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (product && userId){
      SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
      payment.quantity = count;
      payment.applicationUsername = userId;
      [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else{
      NSLog(@"商品没添加 或者 userID没有，无法发起购买");
    }
  });
}

//处理交易状态
-(void)purchaseHandleErrorCode:(NSInteger)code transcation:(SKPaymentTransaction *)transaction description:(NSString *)info
{
  switch (code) {
    case SKPaymentTransactionStateRestored:
      [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
      break;
    case SKPaymentTransactionStateFailed:
      [self purchaseResultHandleWithTransaction:transaction success:NO];
      break;
    default:
      break;
  }
  
  [[NSNotificationCenter defaultCenter]postNotificationName:LCPurchaseProductsResult object:nil userInfo:
   @{@"errorCode":@(code),@"transaction":transaction,@"description":info}];
}


//发送receipt
-(void)purchaseResultHandleWithTransaction:(SKPaymentTransaction *)transaction
                                   success:(BOOL)purchaseSuccess{
  NSData *data = [NSData dataWithContentsOfFile:[[[NSBundle mainBundle] appStoreReceiptURL] path]];
  if (!data) {
    data = transaction.transactionReceipt;
  }
  NSString *receipt = [data base64EncodedStringWithOptions:0];
//  NSLog(@"receipt--------:%@  \n\n\n------",receipt);
  NSError *error;
  NSString *requestContents = [self handlePaymentData:transaction andReceipt:receipt orderSuccess:purchaseSuccess];
  NSData *requestData = [requestContents dataUsingEncoding:NSUTF8StringEncoding];
  if (error){
    NSLog(@"NSJSONSerialization error :%@",error.localizedDescription);
  }
  NSURL * serverURL = [NSURL URLWithString:TestReciptURL];
  NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:serverURL];
  request.HTTPMethod = @"POST";
  request.HTTPBody = requestData;

  [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

  NSURLSession * session = [NSURLSession sharedSession];
  
  NSURLSessionDataTask * task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error){
      NSLog(@"request error :%@",[error localizedDescription]);
    }
    NSError * jsonError = nil;
    NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError) {
      NSLog(@"jsonError:%@",jsonError);
    }
    NSLog(@"response info:%@",dict);
    
    if (purchaseSuccess){
      [self serverValidReceiptWithTransaction:transaction validSuccess:[dict[@"errorCode"] isEqualToString:@"success"]];
    }
    else {
       [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
    
  }];
  [task resume];
}

-(NSString *)handlePaymentData:(SKPaymentTransaction *)transcation
                    andReceipt:(NSString *)receipt
                  orderSuccess:(BOOL)success
{
  SKPayment * payment = transcation.payment;
  NSDateFormatter * formatter = [[NSDateFormatter alloc]init];
  [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  [formatter setLocale:[NSLocale currentLocale]];
  NSDate * transactionDate = transcation.transactionDate ?: [NSDate date];
  NSString * dateString =[formatter stringFromDate:transactionDate];
  NSString * gtmTime = [NSString stringWithFormat:@"%ld",(NSInteger)[transactionDate timeIntervalSince1970]];
  NSDictionary * dict = @{
                          @"orderId":payment.applicationUsername ?: @"",
                          @"receipt":receipt ?:@"",
                          @"transactionId":transcation.transactionIdentifier?:@"",
                          @"orderDateString":dateString ?:@"",
                          @"orderStatus":success ? @"1" : @"-1",
                          @"productId":payment.productIdentifier ?: @"",
                          @"orgOrderDateString":gtmTime
                          };
  NSData * data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
  NSString * jsonString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
  NSString * resultString = [NSString stringWithFormat:@"request_data=%@&token=%@",jsonString,@""];
  return resultString;
}


-(void)serverValidReceiptWithTransaction:(SKPaymentTransaction *)transaction
                            validSuccess:(BOOL)isSuccess{
  NSNumber * errorCode = @(101);
  NSString * des = @"验证失败";
  if (isSuccess) {
     [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
     errorCode = @(100);
    NSString * orderId = transaction.payment.applicationUsername ?: @"没有";
    des = [NSString stringWithFormat:@"%@ : orderId:%@",@"验证成功",orderId];
  }
  [[NSNotificationCenter defaultCenter]postNotificationName:LCPurchaseProductsResult object:nil userInfo:
   @{@"errorCode":errorCode,@"transaction":transaction,@"description":des}];
}



@end
