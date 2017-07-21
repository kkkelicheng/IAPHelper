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
    //打印所有的商品
    for (SKProduct * p in self.products) {
        [p infomationDescription];
    }
    
    NSLog(@"invalidProductIdentifiers:%@",response.invalidProductIdentifiers);
    self.validProducts = [self validProducts:response.products andInvalidIds:response.invalidProductIdentifiers];
    
    //返回能被苹果store识别的商品
    if(self.getProductsBack){
        self.getProductsBack(self.validProducts);
    }
}


#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    for (SKPaymentTransaction *transaction in transactions) {
        [transaction infomationDescription];
      NSString * description = @"";
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:{
                //当这个商品没有结束购买的时候，再次购买会出现这个，会免费恢复
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

#pragma mark - Purchase 对外的接口
// 购买商品！
-(void)purchaseWithProduct:(SKProduct *)product
                 andUserId:(NSString *)userId
                  andCount:(NSInteger)count
{
    if (product && userId){
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = count;
        // 这里 applicationUsername 可以灵活处理，很重要。发挥想象解决业务问题
        // 这个SKPayment app会自己做持久化，即使app删除。所以把需要的信息压缩下记录到服务器，返回一个orderID，可以将这个orderID放到这里
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
        // 假如需要告诉服务器失败，在请求回来之后再结束本地的交易
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
        [self serverValidReceiptResultWithTransaction:transcation andIsSuccess:[dict[@"status"] integerValue] == 0];
          
    }];
    [task resume];
}

//获取凭证
-(NSData *)getReceiptDataWithTranscation:(SKPaymentTransaction *)transcation
{
    //关于票据的持久化 可以看看苹果的文档
    //对于消费型产品：苹果自己在本地更新，删除票据信息。
    //对于非消费型产品：苹果会自己持久化票据信息。
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *data = [NSData dataWithContentsOfURL:receiptURL];
    //If the appStoreReceiptURL method is not available, you can fall back to the value of a transaction's transactionReceipt property for backward compatibility
    return data ?: transcation.transactionReceipt;
}

//receipt去验证后处理
- (void)serverValidReceiptResultWithTransaction:(SKPaymentTransaction *)transaction andIsSuccess:(BOOL)isSuccess
{
    if(isSuccess){
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
    else {
        // 检查一下苹果返回的错误代码
        // POST 到服务器的时候可能会有问题 base64转码的时候加号等会变
    }
}



@end

