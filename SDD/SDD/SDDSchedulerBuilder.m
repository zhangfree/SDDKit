//
//  SDDMachineBuilder.m
//  YYMSAuth
//
//  Created by 黎玉华 on 16/1/22.
//  Copyright © 2016年 YY.Inc. All rights reserved.
//

#import <objc/message.h>
#import <objc/runtime.h>
#import "SDDSchedulerBuilder.h"
#import "SDDScheduler.h"
#import "VCPDynamic.h"
#import "sdd_parser.h"
#import "sdd_array.h"

static const void* kSDDStateBuilderNameKey = &kSDDStateBuilderNameKey;
static const void* kSDDStateBuilderDSLKey  = &kSDDStateBuilderDSLKey;

@interface SDDScheduler(SDDProperties) <VCPDynamic> @end
@implementation SDDScheduler(SDDProperties)

+ (NSArray *)vcp_propertyNames {
    return @[@"sddIdentifier", @"sddName", @"sddDSL", @"sddDomain"];
}

@end

@implementation SDDScheduler (SDDLogSupport)
@dynamic sddIdentifier, sddDSL, sddName, sddDomain;

- (NSString*)description {
    NSString *name = [self sddName];
    if (name == nil)
        return [super description];
    
    return name;
}

@end


#pragma mark -

@interface SDDState (SDDProperties) <VCPDynamic> @end
@implementation SDDState (SDDProperties)

+ (NSArray *)vcp_propertyNames {
    return @[@"sddName"];
}

@end

@implementation SDDState (SDDLogSupport)
@dynamic sddName;

- (NSString*)description {
    NSString *name = [self sddName];
    if (name == nil)
        return [super description];
    
    return name;
}

@end


@implementation NSString (SDDSplitActions)

- (NSArray*)sddNamedComponents {
    NSArray* acts = [self componentsSeparatedByString:@" "];
    if (acts.count == 1 && [acts[0] length] == 0) {
        return @[];
    }
    
    return acts;
}

@end



@interface SDDParserContext : NSObject 
@property (nonatomic, weak) id runtimeContext;
@property (nonatomic, weak) SDDScheduler* scheduler;
@property (nonatomic, weak) NSMutableDictionary<NSString*, SDDState*>* states;
@end

@implementation SDDParserContext

- (SDDState*)stateWithCName:(const char*)cname {
    NSString* name = [NSString stringWithCString:cname encoding:NSUTF8StringEncoding];
    return self.states[name];
}

- (SDDState*)stateWithRawState:(sdd_state*)raw_state {
    return [self stateWithCName:raw_state->name];
}

@end

typedef BOOL (*SDDConditionMsgSendtionImp)(id, SEL);
typedef BOOL (*SDDConditionMsgSendtionImp2)(id, SEL, id);
static SDDConditionMsgSendtionImp SDDConditionMsgSend   = (SDDConditionMsgSendtionImp)objc_msgSend;
static SDDConditionMsgSendtionImp2 SDDConditionMsgSend2 = (SDDConditionMsgSendtionImp2)objc_msgSend;

typedef void (*SDDSimpleActionImp)(id, SEL);
typedef void (*SDDAugmentedActionImp)(id, SEL, id);
static SDDSimpleActionImp SDDSimpleAction       = (SDDSimpleActionImp)objc_msgSend;
static SDDAugmentedActionImp SDDAugmentedAction = (SDDAugmentedActionImp)objc_msgSend;

void SDDSchedulerAddState(void* contextObj, sdd_state* raw_state) {
    __weak SDDParserContext* pcontext = (__bridge SDDParserContext*)contextObj;
    __weak id context = pcontext.runtimeContext;
    
    NSString* entries = [NSString stringWithCString:raw_state->entries encoding:NSUTF8StringEncoding];
    NSString* exits   = [NSString stringWithCString:raw_state->exits   encoding:NSUTF8StringEncoding];
    
    SDDActivation activation = ^(id argument) {
        NSArray* acts = [entries sddNamedComponents];
        for (NSString* act in acts) {
            SEL simpleSel    = NSSelectorFromString(act);
            SEL augmentedSel = NSSelectorFromString([NSString stringWithFormat:@"%@:", act]);
            
            if ([context respondsToSelector:simpleSel]) {
                SDDSimpleAction(context, simpleSel);
            } else if ([context respondsToSelector:augmentedSel]) {
                SDDAugmentedAction(context, augmentedSel, argument);
            } else if (context != nil) {
                [[NSException exceptionWithName:@"SDDSchedulerBuilderException"
                                         reason:[NSString stringWithFormat:@"无法在上下文:%@ 对象中找到 %@ 方法", context, act]
                                       userInfo:@{
                                                  @"context": context ? context : @"null",
                                                  @"action":  act,
                                                  }] raise];
            }
        }
    };
    
    SDDDeactivation deactivation = ^{
        NSArray* acts = [exits sddNamedComponents];
        for (NSString* act in acts) {
            SEL simpleSel    = NSSelectorFromString(act);
            if ([context respondsToSelector:simpleSel]) {
                SDDSimpleAction(context, simpleSel);
            } else if (context != nil) {
                [[NSException exceptionWithName:@"SDDSchedulerBuilderException"
                                         reason:[NSString stringWithFormat:@"无法在上下文:%@ 对象中找到 %@ 方法", context, act]
                                       userInfo:@{
                                                  @"context": context ? context : @"null",
                                                  @"action":  act,
                                                  }] raise];
            }
        }
    };
    
    NSString* name = [NSString stringWithCString:raw_state->name encoding:NSUTF8StringEncoding];
    SDDState* state = [[SDDState alloc] initWithActivation:activation deactivation:deactivation];
    state.sddName = name;
    pcontext.states[name] = state;
    [pcontext.scheduler addState:state];
    [pcontext.scheduler setState:state defaultState:[pcontext stateWithCName:raw_state->default_stub]];
}

void SDDSchedulerSetDescendants(void* contextObj, sdd_state* raw_master, sdd_array* raw_descendants) {
    __weak SDDParserContext* pcontext = (__bridge SDDParserContext*)contextObj;
    
    NSMutableArray* descendants = [NSMutableArray array];
    for (int i=0; i<sdd_array_count(raw_descendants); ++i) {
        sdd_state* raw_state = sdd_array_at(raw_descendants, i, YES);
        [descendants addObject:[pcontext stateWithRawState:raw_state]];
    }
    
    SDDState* master = [pcontext stateWithRawState:raw_master];
    [pcontext.scheduler state:master addMonoStates:descendants];
}

void SDDSchedulerMakeTransition(void* contextObj, sdd_transition* t) {
    __weak SDDParserContext* pcontext = (__bridge SDDParserContext*)contextObj;
    __weak id context = pcontext.runtimeContext;
    
    SDDEvent* event = [NSString stringWithCString:t->event encoding:NSUTF8StringEncoding];
    SDDState* fromState = [pcontext stateWithCName:t->from];
    SDDState* toState   = [pcontext stateWithCName:t->to];
    
    NSString* names = [NSString stringWithCString:t->actions encoding:NSUTF8StringEncoding];
    SDDAction postAction = ^(id argument) {
        NSArray* acts = [names sddNamedComponents];
        for (NSString* act in acts) {
            SEL simpleSel    = NSSelectorFromString(act);
            SEL augmentedSel = NSSelectorFromString([NSString stringWithFormat:@"%@:", act]);
            
            if ([context respondsToSelector:simpleSel]) {
                SDDSimpleAction(context, simpleSel);
            } else if ([context respondsToSelector:augmentedSel]) {
                SDDAugmentedAction(context, augmentedSel, argument);
            } else if (context != nil) {
                [[NSException exceptionWithName:@"SDDSchedulerBuilderException"
                                         reason:[NSString stringWithFormat:@"无法在上下文:%@ 对象中找到 %@ 方法", context, act]
                                       userInfo:@{
                                                  @"context": context ? context : @"null",
                                                  @"action":  act,
                                                  }] raise];
            }
        }
    };
    
    NSString* conditions = [NSString stringWithCString:t->conditions encoding:NSUTF8StringEncoding];
    SDDCondition condition = ^BOOL (id argument) {
        NSArray* components = [conditions sddNamedComponents];
        if (components.count == 0)
            return YES;
        
        NSMutableArray* evalStack = [NSMutableArray array];
        for (NSString* p in components) {
            BOOL exprValue;
            if ([p isEqualToString:@"!"]) {
                BOOL value = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                exprValue = !value;
            } else if ([p isEqualToString:@"|"]) {
                BOOL rightValue = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                BOOL leftValue  = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                exprValue = leftValue || rightValue;
            } else if ([p isEqualToString:@"&"]) {
                BOOL rightValue = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                BOOL leftValue  = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                exprValue = leftValue && rightValue;
            } else if ([p isEqualToString:@"^"]) {
                BOOL rightValue = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                BOOL leftValue  = [[evalStack lastObject] boolValue]; [evalStack removeLastObject];
                exprValue = leftValue ^ rightValue;
            } else {
                SEL simpleSel    = NSSelectorFromString(p);
                SEL augmentedSel = NSSelectorFromString([NSString stringWithFormat:@"%@:", p]);
                if ([context respondsToSelector:simpleSel]) {
                    exprValue = SDDConditionMsgSend(context, simpleSel);
                } else if ([context respondsToSelector:augmentedSel]) {
                    exprValue = SDDConditionMsgSend2(context, augmentedSel, argument);
                } else if (context != nil) {
                    [[NSException exceptionWithName:@"SDDSchedulerBuilderException"
                                             reason:[NSString stringWithFormat:@"无法在上下文:%@ 对象中找到 %@ 方法", context, p]
                                           userInfo:@{
                                                      @"context":   context ? context : @"null",
                                                      @"condition": p,
                                                      }] raise];
                }
            }
            
            [evalStack addObject:@(exprValue)];
        }
        
        return [[evalStack lastObject] boolValue];
    };

    [pcontext.scheduler when:event satisfied:condition transitFrom:fromState to:toState postAction:postAction];
}

void SDDSchedulerBuilderHandleCompletion(void *contextObj, sdd_state *root_state) {
    __weak SDDParserContext* pcontext = (__bridge SDDParserContext*)contextObj;
    
    SDDState *rootState = [pcontext stateWithCName:root_state->name];
    [pcontext.scheduler setRootState:rootState];
    pcontext.scheduler.sddName = [NSString stringWithUTF8String:root_state->name];
}

@implementation SDDSchedulerBuilder {
    NSString*              _namespace;
    id<SDDSchedulerLogger> _logger;
    NSOperationQueue       *_queue;
    SDDEventsPool          *_epool;
    
    NSMutableArray         *_schedulers;
}

- (instancetype)initWithNamespace:(NSString*)namespc logger:(id<SDDSchedulerLogger>)logger queue:(NSOperationQueue*)queue {
    if (self = [super init]) {
        _namespace  = namespc;
        _logger     = logger;
        _queue      = queue;
        
        _schedulers = [NSMutableArray array];
        _epool      = [[SDDEventsPool alloc] init];
    }
    return self;
}

- (void)dealloc {
    for (SDDScheduler *s in _schedulers) {
        [s stop];
    }
}

- (SDDScheduler*)schedulerWithContext:(id)context dsl:(NSString*)dsl {
    SDDScheduler* scheduler = [[SDDScheduler alloc] initWithOperationQueue:_queue logger:_logger];
    scheduler.sddDSL = dsl;
    
    NSMutableDictionary* states = [NSMutableDictionary dictionary];
    
    SDDParserContext* pcontext = [[SDDParserContext alloc] init];
    pcontext.states = states;
    pcontext.runtimeContext = context;
    pcontext.scheduler = scheduler;
    
    sdd_parser_callback callback;
    callback.context = (__bridge void*)pcontext;
    callback.stateHandler      = &SDDSchedulerAddState;
    callback.clusterHandler    = &SDDSchedulerSetDescendants;
    callback.transitionHandler = &SDDSchedulerMakeTransition;
    callback.completionHandler = &SDDSchedulerBuilderHandleCompletion;
    
    sdd_parse([dsl cStringUsingEncoding:NSUTF8StringEncoding], &callback);
    return scheduler;
}

- (void)hostSchedulerWithContext:(id)context dsl:(NSString *)dsl {
    [self hostSchedulerWithContext:context dsl:dsl initialArgument:nil];
}

NSString * SDDMakeUUID() {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);//create a new UUID
    NSString  *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    
    return uuidString ;
}

- (void)hostSchedulerWithContext:(id)context dsl:(NSString *)dsl initialArgument:(id)argument {
    SDDScheduler *scheduler = [self schedulerWithContext:context dsl:dsl];
    scheduler.sddIdentifier = SDDMakeUUID();
    
    [scheduler startWithEventsPool:_epool initialArgument:argument];
    [_schedulers addObject:scheduler];
}

@end
