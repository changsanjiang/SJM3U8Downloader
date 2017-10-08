//
//  UIView+SJExtension.h
//  SJVideoPlayerProject
//
//  Created by BlueDancer on 2017/9/6.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (SJExtension)

@property (nonatomic, assign) CGFloat csj_x;
@property (nonatomic, assign) CGFloat csj_y;
@property (nonatomic, assign) CGFloat csj_w;
@property (nonatomic, assign) CGFloat csj_h;
@property (nonatomic, assign) CGSize  csj_size;
@property (nonatomic, assign) CGFloat csj_centerX;
@property (nonatomic, assign) CGFloat csj_centerY;
@property (nonatomic, assign, readonly) CGFloat csj_maxX;
@property (nonatomic, assign, readonly) CGFloat csj_maxY;

@property (nonatomic, strong, readonly) UIImage *csj_currentSnapshot;
@property (nonatomic, strong, readonly) UIViewController *csj_viewController;

// MARK: -  设置中心点
- (void)csj_centerWithView:(UIView *)view;

// MARK: -  ⚠️ 视图底部 用OC 画虚线, 需要把代码拷贝到 drawRect中.
- (void)csj_lyXuXian;

// MARK: -  切圆
- (void)csj_cornerRadius;

/**  设置圆角  */
- (void)rounded:(CGFloat)cornerRadius;

/**  设置圆角和边框  */
- (void)rounded:(CGFloat)cornerRadius width:(CGFloat)borderWidth color:(UIColor *)borderColor;

/**  设置边框  */
- (void)border:(CGFloat)borderWidth color:(UIColor *)borderColor;

/**   给哪几个角设置圆角  */
-(void)round:(CGFloat)cornerRadius RectCorners:(UIRectCorner)rectCorner;

/**  设置阴影  */
-(void)shadow:(UIColor *)shadowColor opacity:(CGFloat)opacity radius:(CGFloat)radius offset:(CGSize)offset;


+ (CGFloat)getLabelHeightByWidth:(CGFloat)width Title:(NSString *)title font:(UIFont *)font;

- (BOOL)sjHasSubView:(UIView *)subView;

// MARK: Animations

- (void)revealAnimation;

- (void)cubeAnimation;

- (void)rippleEffectAnimation;

- (void)fadeAnimation;

- (void)scaleAnimation;

- (void)praiseAnimationWithFatherView:(UIView *)fatherView;

- (void)praiseAnimationWithFatherView:(UIView *)fatherView complete:(void(^)(void))block;

#pragma mark - 创建视图

+ (UIButton *)roundAttrTitleButtonWithTitle:(NSString *)title imageName:(NSString *)imageName tag:(NSInteger)tag target:(id)target sel:(SEL)sel;

+ (UIButton *)attrTitleButtonWithTitle:(NSString *)title imageName:(NSString *)imageName tag:(NSUInteger)tag target:(id)target sel:(SEL)sel;

+ (UIView *)roundViewWithBackGroundColor:(UIColor *)backgroundColor;

/*!
 *  viewMode is UIViewContentModeScaleAspectFit
 */
+ (UIImageView *)imageViewWithImageStr:(NSString *)imageStr;

+ (UIImageView *)imageViewWithImageStr:(NSString *)imageStr viewMode:(UIViewContentMode)viewMode;

+ (UIImageView *)roundImageViewWithImageStr:(NSString *)imageStr viewMode:(UIViewContentMode)viewMode;

+ (UILabel *)labelWithFontSize:(CGFloat)size textColor:(UIColor *)textColor;

+ (UILabel *)labelWithFontSize:(CGFloat)size textColor:(UIColor *)textColor alignment:(NSTextAlignment)alignment;

+ (UILabel *)labelWithFontSize:(CGFloat)size textColor:(UIColor *)textColor alignment:(NSTextAlignment)alignment backgroundColor:(UIColor *)backgroundColor;

+ (UILabel *)roundLabelWithFontSize:(CGFloat)size textColor:(UIColor *)textColor alignment:(NSTextAlignment)alignment backgroundColor:(UIColor *)backgroundColor;

+ (UILabel *)roundLabelWithFontSize:(CGFloat)size textColor:(UIColor *)textColor alignment:(NSTextAlignment)alignment;

+ (UICollectionView *)collectionViewWithItemSize:(CGSize)itemSize backgroundColor:(UIColor *)backgroundColor;

+ (UICollectionView *)collectionViewWithItemSize:(CGSize)itemSize backgroundColor:(UIColor *)backgroundColor scrollDirection:(UICollectionViewScrollDirection)direction;

+ (UICollectionView *)collectionViewWithItemSize:(CGSize)itemSize backgroundColor:(UIColor *)backgroundColor scrollDirection:(UICollectionViewScrollDirection)direction headerSize:(CGSize)headerSize footerSize:(CGSize)footerSize;

+ (UICollectionView *)collectionViewWithItemSize:(CGSize)size backgroundColor:(UIColor *)backgroundColor scrollDirection:(UICollectionViewScrollDirection)scrollDirection minimumLineSpacing:(CGFloat)minimumLineSpacing minimumInteritemSpacing:(CGFloat)minimumInteritemSpacing;

+ (UIButton *)buttonWithImageName:(NSString *)imageName tag:(NSUInteger)tag target:(id)target sel:(SEL)sel;

+ (UIButton *)buttonWithImageName:(NSString *)imageName title:(NSString *)title tag:(NSUInteger)tag target:(id)target sel:(SEL)sel;

+ (UIButton *)buttonWithImageName:(NSString *)imageName title:(NSString *)title backgroundColor:(UIColor *)backgroundColor tag:(NSUInteger)tag target:(id)target sel:(SEL)sel;

+ (UIButton *)buttonWithImageName:(NSString *)imageName title:(NSString *)title titleColor:(UIColor *)titleColor backgroundColor:(UIColor *)backgroundColor tag:(NSUInteger)tag target:(id)target sel:(SEL)sel;

+ (UIButton *)buttonWithTitle:(NSString *)title backgroundColor:(UIColor *)backgroundColor tag:(NSUInteger)tag target:(id)target sel:(SEL)sel fontSize:(CGFloat)fontSize;

+ (UIButton *)buttonWithTitle:(NSString *)title titleColor:(UIColor *)titleColor backgroundColor:(UIColor *)backgroundColor tag:(NSUInteger)tag target:(id)target sel:(SEL)sel fontSize:(CGFloat)fontSize;


@end
