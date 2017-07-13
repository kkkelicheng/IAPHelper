//
//  ProductsCell.h
//  IAPDemo
//
//  Created by licheng ke on 2017/6/29.
//  Copyright © 2017年 licheng ke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProductsCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *pImage;
@property (weak, nonatomic) IBOutlet UILabel *pTitle;
@property (weak, nonatomic) IBOutlet UILabel *pSubtitle;

@end
