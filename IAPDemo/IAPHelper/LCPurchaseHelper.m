//
//  LCPurchaseHelper.m
//  IAPDemo
//
//  Created by licheng ke on 2017/6/28.
//  Copyright © 2017年 licheng ke. All rights reserved.
//


#import "LCPurchaseHelper.h"


@interface SKPaymentTransaction (InfomationDescirption)

-(void)infomationDescription;

@end

@implementation SKPaymentTransaction (InfomationDescirption)

-(void)infomationDescription{
    NSLog(@"\n\n\n  ---> Transaction Description");
    //    transactionDate
    NSDate * date = self.transactionDate;
    NSDateFormatter * formatter = [[NSDateFormatter alloc]init];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setDateFormat:@"yyyy年MM月dd日 HH时mm分ss秒"];
    NSString * dateString = [formatter stringFromDate:date];
    //transactionIdentifier
    NSArray * states = @[@"SKPaymentTransactionStatePurchasing",
                         @"SKPaymentTransactionStatePurchased",
                         @"SKPaymentTransactionStateFailed",
                         @"SKPaymentTransactionStateRestored",
                         @"SKPaymentTransactionStateDeferred"];
    
    NSLog(@"Transaction error:%@",self.error?[self.error description]:@"null");
    NSLog(@"Transaction date:%@",dateString);
    NSLog(@"Transaction id:%@",self.transactionIdentifier);
    NSLog(@"Transaction state:%@",states[self.transactionState]);
    
    //SKPayment
    NSLog(@"Payment productID:%@",self.payment.productIdentifier);
    NSLog(@"Payment productQuantity:%@",@(self.payment.quantity));
    NSLog(@"Payment productBuyer:%@",self.payment.applicationUsername);
    NSLog(@"----< \n");
}

@end

@interface SKProduct (ProductDescription)

-(void)infomationDescription;

@end

@implementation SKProduct (ProductDescription)

-(void)infomationDescription
{
    NSLog(@"...>>>  \n");
    NSLog(@"localizedTitle                      -->  %@", [self localizedTitle]);
    NSLog(@"localizedDescription                -->  %@", [self localizedDescription]);
    NSLog(@"price                               -->  %@", [self price]);
    NSLog(@"priceLocale NSLocaleCurrencySymbol  -->  %@", [self.priceLocale objectForKey:NSLocaleCurrencySymbol]);
    NSLog(@"priceLocale NSLocaleCurrencyCode    -->  %@", [self.priceLocale objectForKey:NSLocaleCurrencyCode]);
    NSLog(@"productIdentifier                   -->  %@", [self productIdentifier]);
}

@end

NSString * const TestReciptURL = @"https://sandbox.itunes.apple.com/verifyReceipt";
NSString * const ProductionReciptURL = @"https://buy.itunes.apple.com/verifyReceipt";


static LCPurchaseHelper * helper = nil;

@interface LCPurchaseHelper ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

@property (nonatomic,strong) SKProductsRequest * pRequest;
@property (nonatomic,copy) void(^getProductsBack)(NSArray<SKProduct *> *);

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

-(void)getProductsWithIndentifies:(NSArray *)ids andProductsBack:(void(^)(NSArray<SKProduct *> *))callBack
{
    self.getProductsBack = callBack;
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
        [p infomationDescription];
    }
    
    if(self.getProductsBack){
        self.getProductsBack(self.products);
    }

}


#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *transaction in transactions) {
        [transaction infomationDescription];
      NSString * description = @"";
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:{
                description = @"交易已经提交";
              [self purchaseProductFailed:transaction withDescription:description];
                break;
            }
            case SKPaymentTransactionStateDeferred: {
                description = @"交易正在处理中";
              [self purchaseProductFailed:transaction withDescription:description];
                break;
            }
            case SKPaymentTransactionStateRestored:{
                description = @"交易恢复购买商品";
              [self purchaseHasRestoreWithTransaction:transaction andDescription:description];
                break;
            }
            case SKPaymentTransactionStateFailed: {
                description = @"交易失败";
              [self purchaseProductFailed:transaction withDescription:description];
            }
                break;
            case SKPaymentTransactionStatePurchased:{
                description = @"购买完成,向自己的服务器验证";
                [self purchaseSuccessWithTransaction:transaction];
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
    if (product && userId){
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = count;
        payment.applicationUsername = userId;
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
    else{
        NSLog(@"商品没添加 或者 userID没有，无法发起购买");
    }
}

//购买已经交易过
-(void)purchaseHasRestoreWithTransaction:(SKPaymentTransaction *)transaction andDescription:(NSString *)description
{
  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

//购买失败
-(void)purchaseProductFailed:(SKPaymentTransaction *)transaction withDescription:(NSString *)description
{
    if(transaction.error){
        NSLog(@"交易失败信息：%@",transaction.error);
        [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    }
}

//发送receipt给苹果
-(void)purchaseSuccessWithTransaction:(SKPaymentTransaction *)transaction{
    NSLog(@"购买成功：transaction：%@",transaction);
    NSString *receipt = [[self getReceiptDataWithTranscation:transaction] base64EncodedStringWithOptions:0];
    if (!receipt) {
        NSLog(@"没有获取到凭证，本地无凭证或者无交易对象");
        return ;
    }
    [self verifyReciptInAppWithReceiptString:receipt andTranscation:transaction];
}

-(void)verifyReciptInAppWithReceiptString:(NSString *)receipt andTranscation:(SKPaymentTransaction *)transcation
{
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": receipt
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    NSURL *storeURL = [NSURL URLWithString:TestReciptURL];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:storeURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = requestData;
    
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
        if([dict[@"status"] integerValue] == 0){
            //            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        }
    }];
    [task resume];
}

//获取凭证
-(NSData *)getReceiptDataWithTranscation:(SKPaymentTransaction *)transcation
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *data = [NSData dataWithContentsOfURL:receiptURL];
    return data ?: transcation.transactionReceipt;
}

//receipt去苹果验证成功后
-(void)serverValidReceiptSuccessWithTransaction:(SKPaymentTransaction *)transaction{
  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

//receipt去苹果验证失败后
-(void)serverValidReceiptFailedWithTransaction:(SKPaymentTransaction *)transaction
{
}


@end

