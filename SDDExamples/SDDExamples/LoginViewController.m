//
//  LoginViewController.m
//  SDDExamples
//
//  Created by Tom Zhang on 16/5/18.
//  Copyright © 2016年 yy. All rights reserved.
//

#import "LoginViewController.h"
#import <SDDI/SDDI.h>
#import "Context.h"

static NSString* const kLVCTimesUp                  = @"TimesUp";
static NSString* const kLVCDidTouchSMSCodeButton    = @"DidTouchSMSCodeButton";
static NSString* const kLVCDidTouchVerifyButton     = @"DidTouchVerifyButton";
static NSString* const kLVCDidChangeTextFields      = @"DidChangeTextFields";
static NSString* const kLVCDidChangePhoneNumber     = @"DidChangePhoneNumber";
static NSString* const kLVCDoneVerifying            = @"DoneVerifying";
static NSString* const kLVCShouldHideFailureTip     = @"ShouldHideFailureTip";

@interface UIColor (LVCDisableColor)
+ (UIColor*)LVCButtonDisableColor;
+ (UIColor*)LVCButtonOrangeColor;
@end

@implementation UIColor (LVCDisableColor)
+ (UIColor*)LVCButtonDisableColor {
    return [UIColor colorWithRed:1.0/3.0 green:1.0/3.0 blue:1.0/3.0 alpha:0.5];
}

+ (UIColor*)LVCButtonOrangeColor {
    return [UIColor colorWithRed:1.0 green:180.0/255.0 blue:0 alpha:1.0];
}
@end

@interface LoginViewController()<UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UIView *grayMaskView;
@property (nonatomic, weak) IBOutlet UITextField *phoneNumberField;
@property (nonatomic, weak) IBOutlet UIView *grayMaskView2;
@property (nonatomic, weak) IBOutlet UITextField *SMSCodeField;
@property (nonatomic, weak) IBOutlet UIButton *SMSCodeRequestingButton;
@property (nonatomic, weak) IBOutlet UIButton *verifyButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *indicator;
@property (nonatomic, weak) IBOutlet UILabel *failureTip;

@end

@implementation LoginViewController {
    SDDSchedulerBuilder *_builder;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    NSMutableArray* views = [@[self.view] mutableCopy];
    while( views.count > 0 ) {
        UIView* v = views.firstObject;
        [views removeObjectAtIndex:0];
        [views addObjectsFromArray:v.subviews];
        
        NSArray* constraints = v.constraints;
        for (NSLayoutConstraint* c in constraints) {
            if ((c.firstAttribute == NSLayoutAttributeHeight || c.firstAttribute == NSLayoutAttributeWidth) && (fabs(c.constant - 1.0) < 0.05)) {
                c.constant = 1.0 / UIScreen.mainScreen.scale;
            }
        }
    }
}

-(void)disableSMSButton {
    self.SMSCodeRequestingButton.enabled = NO;
    self.SMSCodeRequestingButton.backgroundColor = [UIColor LVCButtonDisableColor];
}

-(void)enableSMSButton {
    self.SMSCodeRequestingButton.enabled = YES;
    self.SMSCodeRequestingButton.backgroundColor = [UIColor blueColor];
}

-(void)restoreSMSButtonTitle {
    [self.SMSCodeRequestingButton setTitle:@"获取验证码" forState:UIControlStateNormal];
}

-(void)startCountDown {
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int remainingTime = 30;
        while (wself && remainingTime > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.SMSCodeRequestingButton setTitle:[NSString stringWithFormat:@"%d秒后重试", remainingTime]
                                               forState:UIControlStateNormal];
            });
            remainingTime--;
            sleep(1);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SDDEventsPool defaultPool] scheduleEvent:kLVCTimesUp];
        });
    });
}

-(void)requestSMSCode {
    // Do Something.
}

-(BOOL)isPhoneNumber {
    static NSPredicate* predicate;
    if (!predicate) {
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES \"^1\\\\d{10}\""];
    }
    return [predicate evaluateWithObject:self.phoneNumberField.text];
}

-(void)enablePhoneNumberField {
    self.phoneNumberField.enabled = YES;
    self.grayMaskView.hidden = YES;
}

-(void)disablePhoneNumberField {
    self.phoneNumberField.enabled = NO;
    self.grayMaskView.hidden = NO;
}

-(void)enableSMSCodeField {
    self.SMSCodeField.enabled = YES;
    self.grayMaskView2.hidden = YES;
}

-(void)disableSMSCodeField {
    self.SMSCodeField.enabled = NO;
    self.grayMaskView2.hidden = NO;
}

-(void)resetSMSCodeField {
    self.SMSCodeField.text = @"";
}

-(void)focusOnSMSCodeField {
    [self.SMSCodeField becomeFirstResponder];
}

-(BOOL)isValidCode {
    static NSPredicate* predicate;
    if (!predicate) {
        predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES \"^\\\\d{6}\""];
    }
    return [predicate evaluateWithObject:self.SMSCodeField.text];
}

-(BOOL)isValidInput {
    return [self isPhoneNumber] && [self isValidCode];
}

-(void)disableVerifyButton {
    self.verifyButton.enabled = NO;
    self.verifyButton.backgroundColor = [UIColor LVCButtonDisableColor];
}

-(void)enableVerifyButton {
    self.verifyButton.enabled = YES;
    self.verifyButton.backgroundColor = [UIColor LVCButtonOrangeColor];
}

-(void)performMockLogin {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(5);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNumber *verify;
            if ([self.phoneNumberField.text isEqualToString:@"15012345678"] && [self.SMSCodeField.text isEqualToString:@"654321"]) {
                verify = [NSNumber numberWithInteger:88888888];
            }
            [[SDDEventsPool defaultPool] scheduleEvent:kLVCDoneVerifying withParam:verify];
        });
    });
}

-(void)performLogin {
    [self performMockLogin];
}

-(BOOL)isLoginSucceed:(NSNumber*)verify{
    return [verify integerValue] > 0;
}

-(void)handleLoginSuccess {
    if (self.successHandler) {
        self.successHandler();
    }
}

-(void)hideActivityIndicator {
    [self.indicator stopAnimating];
}

-(void)showActivityIndicator {
    [self.indicator startAnimating];
}

-(void)hideFailureTip {
    [UIView animateWithDuration:0.25 animations:^{
        self.failureTip.alpha = 0.0;
    }];
}

-(void)showFailureTip {
    [UIView animateWithDuration:0.25 animations:^{
        self.failureTip.alpha = 1.0;
    }];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(1.5);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SDDEventsPool defaultPool] scheduleEvent:kLVCShouldHideFailureTip];
        });
    });
}

-(void)setupSDD {
    _builder = [[SDDSchedulerBuilder alloc] initWithNamespace:@"loginVC"
                                                       logger:globalContext.reporter
                                                        queue:[NSOperationQueue currentQueue]
                                                   eventsPool:[SDDEventsPool defaultPool]];
}

-(void)setupSMSButtonState {
    NSString* dsl = SDDOCLanguage
    (
        [SMSButton ~[Disabled]
         [Disabled e:disableSMSButton]
         [Normal   e:enableSMSButton]
         [CountDown
          e:disableSMSButton startCountDown requestSMSCode
          x:restoreSMSButtonTitle
          ]
         ]
         
         [Disabled]     ->  [Normal]:       DidChangeTextFields(isPhoneNumber)
         [Normal]       ->  [Disabled]:     DidChangeTextFields(!isPhoneNumber)
         [Normal]       ->  [CountDown]:    DidTouchSMSCodeButton
         [CountDown]    ->  [Normal]:       TimesUp(isPhoneNumber)
         [CountDown]    ->  [Disabled]:     TimesUp(!isPhoneNumber)
    );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)setupPhoneNumberFieldState {
    NSString* dsl = SDDOCLanguage
    (
        [PhoneNumberField ~[Normal]
         [Normal    e:enablePhoneNumberField]
         [Disabled  e:disablePhoneNumberField]
         ]
     
        [Normal]    ->  [Disabled]:    DidTouchSMSCodeButton
        [Disabled]  ->  [Normal]:      TimesUp
    );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)setupSMSCodeFieldState {
    NSString* dsl = SDDOCLanguage
    (
        [SMSCodeField ~[Disabled]
         [Disabled  e:disableSMSCodeField]
         [Normal    e:enableSMSCodeField resetSMSCodeField]
         ]
     
        [Disabled]    ->  [Normal]:     DidTouchSMSCodeButton/focusOnSMSCodeField
        [Normal]      ->  [Disabled]:   DidChangePhoneNumber
    );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)setupVerifyButtonState {
    NSString* dsl = SDDOCLanguage
    (
        [VerifyButton ~[Disabled]
         [Disabled      e:disableVerifyButton]
         [Normal        e:enableVerifyButton]
         [Verifying     e:disableVerifyButton dismissKeyboard]
         [Success       e:disableVerifyButton handleLoginSuccess]
         ]
     
        [Disabled]     ->  [Normal]:    DidChangeTextFields(isValidInput)
        [Normal]       ->  [Disabled]:  DidChangeTextFields(!isValidInput)
        [Normal]       ->  [Verifying]: DidTouchVerifyButton/performLogin
        [Verifying]    ->  [Normal]:    DoneVerifying(!isLoginSucceed)
        [Verifying]    ->  [Success]:   DoneVerifying(isLoginSucceed)
    );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)setupActivityIndicatorState {
    NSString* dsl = SDDOCLanguage
    (
        [ActivityIndicator ~[Hidden]
         [Hidden    e:hideActivityIndicator]
         [Shown     e:showActivityIndicator]
         ]
     
        [Hidden]    ->  [Shown]:   DidTouchVerifyButton
        [Shown]     ->  [Hidden]:  DoneVerifying
    );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)setupFailureTipState {
    NSString* dsl = SDDOCLanguage
    (
        [FailureTip ~[Hidden]
         [Hidden    e:hideFailureTip]
         [Shown     e:showFailureTip]
         ]
     
     [Hidden]    ->  [Shown]:   DoneVerifying(!isLoginSucceed)
     [Shown]     ->  [Hidden]:  ShouldHideFailureTip
     );
    
    [_builder hostSchedulerWithContext:self dsl:dsl];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [self.phoneNumberField becomeFirstResponder];
    self.phoneNumberField.delegate = self;
    self.SMSCodeField.delegate = self;
    [self setupSDD];
    [self setupSMSButtonState];
    [self setupPhoneNumberFieldState];
    [self setupSMSCodeFieldState];
    [self setupVerifyButtonState];
    [self setupActivityIndicatorState];
    [self setupFailureTipState];
}

- (IBAction)phoneNumberTextDidChange:(UITextField *)sender {
    [[SDDEventsPool defaultPool] scheduleEvent:kLVCDidChangeTextFields];
    [[SDDEventsPool defaultPool] scheduleEvent:kLVCDidChangePhoneNumber];
}

- (IBAction)SMSCodeTextDidChange:(UITextField *)sender {
    [[SDDEventsPool defaultPool] scheduleEvent:kLVCDidChangeTextFields];
}

- (IBAction)didTouchSMSButton:(id)sender {
    [[SDDEventsPool defaultPool] scheduleEvent:kLVCDidTouchSMSCodeButton];
}

- (IBAction)didTouchStopButton:(id)sender {
    if (self.closingHandler) {
        self.closingHandler();
    }
}

- (IBAction)didTouchVerifyButton:(id)sender {
    [[SDDEventsPool defaultPool] scheduleEvent:kLVCDidTouchVerifyButton];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)dismissKeyboard {
    [self.view endEditing:YES];
}
@end