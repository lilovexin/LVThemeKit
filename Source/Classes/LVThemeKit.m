//
//  LVThemeKit.m
//  LVThemeKit
//
//  Created by lvpengwei on 2019/3/30.
//  Copyright © 2019 lvpengwei. All rights reserved.
//

#import "LVThemeKit.h"
#import "LVThemeResource.h"

@implementation LVThemeKitConfig
@end

@interface LVThemeObject<K> ()
@property (nonatomic, weak, readwrite) K tk;
@end
@implementation LVThemeObject
- (instancetype)initWithTK:(id)tk {
    self = [super init];
    if (self) {
        self.tk = tk;
        [self addObservers];
    }
    return self;
}
+ (NSArray *)keyPaths {
    return @[];
}
- (void)addObservers {
    for (NSString *key in [self class].keyPaths) {
        [self addObserverForKeyPath:key];
    }
}
- (void)addObserverForKeyPath:(NSString *)key {
    [self addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:nil];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [self.tk themeObject:self property:keyPath valueChanged:[self valueForKey:keyPath]];
}
- (void)dealloc {
    for (NSString *key in [self class].keyPaths) {
        [self removeObserver:self forKeyPath:key];
    }
}
@end

@interface LVThemeKit<T, V> ()
@property (nonatomic, strong, readwrite) NSArray<T> *themes;
@property (nonatomic, weak, readwrite) V view;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<LVThemeKitCancelable>> *observers;
@property (nonatomic, weak) id readerObserver;
@property (nonatomic, weak) id appObserver;
@property (nonatomic, weak) id qdObserver;
@end
@implementation LVThemeKit
static LVThemeKitConfig *_config = nil;
+ (void)setConfig:(LVThemeKitConfig *)config {
    if (_config != config) {
        _config = config;
    }
}
+ (LVThemeKitConfig *)config {
    return _config;
}
+ (Class)tClass {
    @throw [[NSException alloc] initWithName:@"主动异常" reason:@"子类实现" userInfo:nil];
}
- (id)theme {
    return self.themes[0];
}
+ (instancetype)instanceWithView:(id)view {
    return [[self alloc] initWithView:view tClass:[self tClass]];
}
- (instancetype)initWithView:(id)view tClass:(Class)clz {
    self = [super init];
    if (self) {
        self.view = view;
        NSAssert(LVThemeKit.config != nil, @"LVThemeKit.config 不能为空");
        NSMutableArray *themes = @[].mutableCopy;
        for (LVThemeKitObserveGenerator generator in LVThemeKit.config.generators) {
            [themes addObject:[[clz alloc] initWithTK:self]];
        }
        self.themes = themes.copy;
        self.observers = @{}.mutableCopy;
    }
    return self;
}
- (void)themeObject:(id)object property:(NSString *)key valueChanged:(LVThemeResource *)res {
    [self setupThemeObserve:object property:key valueChanged:res];
    [self applyProperty:key];
}
- (void)applyProperty:(NSString *)key {
    if (LVThemeKit.config.applyProperty) {
        __weak typeof(self) weakSelf = self;
        LVThemeKit.config.applyProperty(self, key, ^(id  _Nonnull theme) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf apply:theme key:key];
        });
        return;
    }
    for (id theme in self.themes) {
        if ([theme valueForKey:key]) {
            [self apply:theme key:key];
            return;
        }
    }
}
- (void)setupThemeObserve:(id)object property:(NSString *)key valueChanged:(LVThemeResource *)res {
    NSInteger index = -1;
    for (id t in self.themes) {
        index += 1;
        if (object == t) break;
    }
    if (index < 0 || index >= self.themes.count) return;
    if (self.observers[@(index)]) return;
    __weak typeof(self) weakSelf = self;
    id cancelable = LVThemeKit.config.generators[index](^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf apply];
    });
    if (cancelable == nil) return;
    self.observers[@(index)] = cancelable;
}
- (void)apply:(id)object key:(NSString *)key {
    if ([self.view isKindOfClass:[CALayer class]]) {
        id resValue = ((LVThemeResource *)[object valueForKey:key]).resValue;
        if ([resValue isKindOfClass:[UIColor class]]) {
            [(CALayer *)self.view setValue:(id)((UIColor *)resValue).CGColor forKey:key];
        }
    } else {
        [self.view setValue:((LVThemeResource *)[object valueForKey:key]).resValue forKey:key];
    }
}
- (void)dealloc {
    for (id<LVThemeKitCancelable> cancelable in self.observers.allValues) {
        [cancelable cancel];
    }
}
- (void)apply {
    for (NSString *key in [[[self class] tClass] keyPaths]) {
        [self applyProperty:key];
    }
}
@end