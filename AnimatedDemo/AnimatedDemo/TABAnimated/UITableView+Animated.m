//
//  UITableView+Animated.m
//  AnimatedDemo
//
//  Created by tigerAndBull on 2018/9/14.
//  Copyright © 2018年 tigerAndBull. All rights reserved.
//

#import "UITableView+Animated.h"

#import <objc/runtime.h>

#import "TABViewAnimated.h"
#import "TABBaseTableViewCell.h"
#import "TABAnimatedObject.h"
#import "TABAnimated.h"

@implementation UITableView (Animated)

struct {
    unsigned int sectionAnimatedCountDelegate:1;
} tableViewAnimatedDelegateRespondTo;

+ (void)load {
    
    // Ensure that the exchange method executed only once.
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        // Gets the viewDidLoad method to the class,whose type is a pointer to a objc_method structure.
        Method originMethod = class_getInstanceMethod([self class], @selector(setDelegate:));
        // Get the method you created.
        Method newMethod = class_getInstanceMethod([self class], @selector(tab_setDelegate:));
        method_exchangeImplementations(originMethod, newMethod);
    });
}

- (void)tab_setDelegate:(id<UITableViewDelegate>)delegate {
    
    SEL oldSelector = @selector(tableView:numberOfRowsInSection:);
    SEL newSelector = @selector(tab_tableView:numberOfRowsInSection:);
    
    SEL old = @selector(tableView:willDisplayCell:forRowAtIndexPath:);
    SEL new = @selector(tab_tableView:willDisplayCell:forRowAtIndexPath:);
    
    SEL oldCell = @selector(tableView:cellForRowAtIndexPath:);
    SEL newCell = @selector(tab_tableView:cellForRowAtIndexPath:);
    
    SEL oldHeightDelegate = @selector(tableView:heightForRowAtIndexPath:);
    SEL newHeightDelegate = @selector(tab_tableView:heightForRowAtIndexPath:);
    
    if ([self respondsToSelector:newSelector]) {
        [self exchangeTableDelegateMethod:oldSelector withNewSel:newSelector withTableDelegate:delegate];
        [self exchangeTableDelegateMethod:old withNewSel:new withTableDelegate:delegate];
        [self exchangeTableDelegateMethod:oldCell withNewSel:newCell withTableDelegate:delegate];
        [self exchangeTableDelegateMethod:oldHeightDelegate withNewSel:newHeightDelegate withTableDelegate:delegate];
    }

    [self tab_setDelegate:delegate];
}

#pragma mark - TABTableViewDataSource

- (NSInteger)tab_tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    // If the animation running, return animatedCount.
    if (tableView.isAnimating) {
        if (tableView.animatedDelegate &&
            [tableView.animatedDelegate respondsToSelector:@selector(tableView:numberOfAnimatedRowsInSection:)]) {
            return [tableView.animatedDelegate tableView:tableView numberOfAnimatedRowsInSection:section];
        }
        return tableView.animatedCount;
    }
    return [self tab_tableView:tableView numberOfRowsInSection:section];
}

- (CGFloat)tab_tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([TABViewAnimated sharedAnimated].isUseTemplate) {
        if (tableView.animatedStyle == TABViewAnimationStart) {
            
            NSAssert(tableView.tabAnimated, @"TABAnimated强制提醒 - tableView未注册模版类");
            
            NSInteger index = indexPath.section;
            if (indexPath.section > (tableView.tabAnimated.classNameArray.count - 1)) {
                index = tableView.tabAnimated.classNameArray.count - 1;
                NSLog(@"TABAnimated提醒 - section的数量和模版类的数量不一致，超出的section，将使用最后一个模版类加载");
            }
            
            SEL sel = @selector(cellHeight);
            tab_suppressPerformSelectorLeakWarning(
                NSNumber *num = [NSClassFromString(tableView.tabAnimated.classNameArray[index]) performSelector:sel];
                if (num.floatValue <= 1.0) {
                    NSAssert(NO, @"TABAnimated提醒 - 请在注册的模版类中设置固定高度，否则没有动画效果");
                }
                return [num floatValue];
            );
        }
        return [self tab_tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return [self tab_tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (UITableViewCell *)tab_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // If the animation running, return animatedCount.
    if ([TABViewAnimated sharedAnimated].isUseTemplate) {
        if (tableView.animatedStyle == TABViewAnimationStart) {
            
            NSInteger index = indexPath.section;
            if (indexPath.section > (tableView.tabAnimated.classNameArray.count - 1)) {
                index = tableView.tabAnimated.classNameArray.count - 1;
                NSLog(@"TABAnimated提醒 - section的数量和模版类的数量不一致，超出的section，将使用最后一个模版类加载");
            }
            
            TABBaseTableViewCell *cell = (TABBaseTableViewCell *)NSClassFromString(tableView.tabAnimated.classNameArray[index]).new;
            return cell;
        }
        return [self tab_tableView:tableView cellForRowAtIndexPath:indexPath];
    }
    return [self tab_tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)tab_tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.animatedStyle == TABViewAnimationStart) {
        return;
    }
    [self tab_tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}

#pragma mark - Private Methods


/**
 exchange method
 
 @param oldSelector old method's sel
 @param newSelector new method's sel
 @param delegate return nil
 */
- (void)exchangeTableDelegateMethod:(SEL)oldSelector
                         withNewSel:(SEL)newSelector
                  withTableDelegate:(id<UITableViewDelegate>)delegate {
    
    Method oldMethod = class_getInstanceMethod([delegate class], oldSelector);
    Method newMethod = class_getInstanceMethod([self class], newSelector);
    
    if ([self isKindOfClass:[delegate class]]) {
           method_exchangeImplementations(oldMethod, newMethod);
    }else {
        
        if (oldMethod == nil) {
            return;
        }
        
        // 代理对象添加newMethod，指向oldImp
        BOOL isVictory = class_addMethod([delegate class], newSelector, class_getMethodImplementation([delegate class], oldSelector), method_getTypeEncoding(oldMethod));
        if (isVictory) {
            // 添加成功后，将oldMethod指向当前类的新的
            class_replaceMethod([delegate class], oldSelector, class_getMethodImplementation([self class], newSelector), method_getTypeEncoding(newMethod));
        }
    }
}

#pragma mark - Public Method

- (void)registerTemplateClass:(Class)templateClass {
    
    if (![templateClass.new isKindOfClass:[TABBaseTableViewCell class]]) {
        NSAssert(NO,@"TABAnimated强制提醒 - 注册类未继承模版类:TABBaseTableViewCell");
    }
    
    TABAnimatedObject *obj = [[TABAnimatedObject alloc] init];
    obj.classNameArray = @[NSStringFromClass(templateClass)];
    self.tabAnimated = obj;
}

- (void)registerTemplateClassArray:(NSArray<Class> *)classArray {
    
    if (nil == classArray || classArray.count <= 0) {
        NSAssert(NO,@"TABAnimated强制提醒 - 请传入有效模版数组");
    }
    
    for (Class templateClass in classArray) {
        if (![templateClass.new isKindOfClass:[TABBaseTableViewCell class]]) {
            NSAssert(NO,@"TABAnimated强制提醒 - 注册类未继承模版类:TABBaseTableViewCell");
        }
    }
    
    TABAnimatedObject *obj = [[TABAnimatedObject alloc] init];
    NSMutableArray *array = @[].mutableCopy;
    for (Class class in classArray) {
        [array addObject:NSStringFromClass(class)];
    }
    
    obj.classNameArray = array.mutableCopy;
    self.tabAnimated = obj;
}

#pragma mark - Getter / Setter

- (void)setAnimatedStyle:(TABViewAnimationStyle)animatedStyle {
    
    // If the animation started, disable touch events.
    if (animatedStyle == TABViewAnimationStart ||
        animatedStyle == TABViewAnimationRunning) {
        [self setScrollEnabled:NO];
        [self setAllowsSelection:NO];
    } else {
        [self setScrollEnabled:YES];
        [self setAllowsSelection:YES];
    }
    objc_setAssociatedObject(self, @selector(animatedStyle), @(animatedStyle), OBJC_ASSOCIATION_ASSIGN);
}

- (NSInteger)animatedCount {
    NSNumber *value = objc_getAssociatedObject(self, @selector(animatedCount));
    return (value.integerValue == 0)?(3):(value.integerValue);
}

- (void)setAnimatedCount:(NSInteger)animatedCount {
    objc_setAssociatedObject(self, @selector(animatedCount), @(animatedCount), OBJC_ASSOCIATION_ASSIGN);
}

- (id<UITableViewAnimatedDelegate>)animatedDelegate {
    id<UITableViewAnimatedDelegate> delegate = objc_getAssociatedObject(self, @selector(animatedDelegate));
    return delegate;
}

- (void)setAnimatedDelegate:(id<UITableViewAnimatedDelegate>)animatedDelegate {
    if (self.animatedDelegate != animatedDelegate) {
        objc_setAssociatedObject(self, @selector(animatedDelegate), animatedDelegate, OBJC_ASSOCIATION_ASSIGN);
        tableViewAnimatedDelegateRespondTo.sectionAnimatedCountDelegate = [animatedDelegate respondsToSelector:@selector(tableView:numberOfAnimatedRowsInSection:)];
    }
}

- (TABAnimatedObject *)tabAnimated {
    return objc_getAssociatedObject(self, @selector(tabAnimated));
}

- (void)setTabAnimated:(TABAnimatedObject *)tabAnimated {
    objc_setAssociatedObject(self, @selector(tabAnimated),tabAnimated, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
