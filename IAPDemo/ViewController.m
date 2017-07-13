//
//  ViewController.m
//  IAPDemo
//
//  Created by licheng ke on 2017/6/28.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

#import "ViewController.h"
#import "LCPurchaseHelper.h"
#import "ProductsCell.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong) NSArray * productsIds;
@property (weak, nonatomic) IBOutlet UITableView *myTableView;
@property (nonatomic,strong) NSMutableArray<SKProduct *> * products;
@property (nonatomic,strong) LCPurchaseHelper * pHelper;
@end

@implementation ViewController

- (NSMutableArray<SKProduct *> *)products
{
    if(!_products){
        _products = [NSMutableArray array];
    }
    return _products;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.productsIds = @[
                         @"com.mplus.test.IAPProduct01",
                         @"com.mplus.test.IAPProduct02",
                         @"com.mplus.test.IAPProduct03",
                         @"com.mplus.test.IAPProduct04"
                         ];
    self.myTableView.tableFooterView = [UIView new];
    self.pHelper = [LCPurchaseHelper share];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - tableview

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"select cell");
    SKProduct * p = self.products[indexPath.row];
    [self.pHelper purchaseWithProduct:p andUserId:@"klc" andCount:1];
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.products.count;
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SKProduct * p = self.products[indexPath.row];
    ProductsCell * cell = [tableView dequeueReusableCellWithIdentifier:@"abc"];
    cell.pTitle.text = p.localizedTitle;
    cell.pSubtitle.text = [NSString stringWithFormat:@"%@ %@ %@",p.productIdentifier,p.price,p.localizedDescription];
    return cell;
    
}

#pragma mark - actions
- (IBAction)requestProducts:(id)sender
{
    NSLog(@"requestProducts");
    [self.pHelper getProductsWithIndentifies:self.productsIds andProductsBack:^(NSArray<SKProduct *> * products) {
        self.products = [products mutableCopy];
        [self.myTableView reloadData];
    }];
}



@end
