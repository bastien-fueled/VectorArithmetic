
#import "SHAlertViewController.h"
#import <SHPresenterBlocks.h>
@import QuartzCore;

@interface SHAlertViewControllerManager : NSObject
@property(nonatomic,strong) NSMutableDictionary     * blocksAlert;
@property(nonatomic,strong) NSMutableDictionary     * blocksContent;
@property(nonatomic,strong) NSMutableDictionary     * blocksButton;
@property(nonatomic,strong) NSMutableDictionary     * paddingType;
@property(nonatomic,strong) NSMutableDictionary     * blocksAnimation;

+(instancetype)sharedManager;

@end

@implementation SHAlertViewControllerManager

#pragma mark - Init & Dealloc
-(instancetype)init; {
  self = [super init];
  if (self) {
    self.blocksAlert       = @{}.mutableCopy;
    self.blocksContent     = @{}.mutableCopy;
    self.blocksButton      = @{}.mutableCopy;
    self.paddingType       = @{}.mutableCopy;
    self.blocksAnimation   = @{}.mutableCopy;
  }
  
  return self;
}


+(instancetype)sharedManager; {
  static id _sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _sharedInstance = [[[self class] alloc] init];
  });
  
  return _sharedInstance;
  
}

@end

@interface SHAlertViewController ()
<UIScrollViewDelegate>

@property(nonatomic,strong)   NSMapTable * buttonCallbacks;
@property(nonatomic,readonly) NSArray    * buttons;
@property(nonatomic,strong) id observerToBackground;
@property(nonatomic,strong) UIView   * alertView;
@property(nonatomic,strong) UILabel  * lblTitle;
@property(nonatomic,strong) UILabel  * lblMessage;
@property(nonatomic,strong) NSLayoutConstraint  * centerConstraint;

@property(nonatomic,copy) SHAlertViewControllerCompletionBlock completion;
@property(nonatomic,weak) SHPresenterBlocks * presenter;

@property(nonatomic,readonly) NSString * alertStyle;
@property(nonatomic,assign,getter = isKeyboardVisible) BOOL keyboardVisible;
@property(nonatomic,assign) SHAlertViewControllerDismissSwipeDirection swipeDirection;
+(void)setupInitialStyling;
-(void)setupLayoutAlert;
-(void)setupLayoutTitle;
-(void)setupLayoutMessage;
-(void)setupLayoutButtons;

-(void)dismissWithClickedButtonIndex:(NSInteger)theButtonIndex animated:(BOOL)theAnimatedFlag;
@end


@implementation SHAlertViewController

+(instancetype)alertWithTitle:(NSString *)theTitle
                      message:(NSString *)theMessage
                 buttonTitles:(NSArray *)theButtonTitles
                   completion:(SHAlertViewControllerCompletionBlock)theCompletion; {
  [self setupInitialStyling];

  SHAlertViewController * viewController = [[[self class] alloc] init];
  viewController.title = theTitle;
  viewController.message = theMessage;
  viewController.completion = theCompletion;
  [theButtonTitles enumerateObjectsUsingBlock:^(NSString * buttonTitle, __unused NSUInteger idx, __unused BOOL *stop) {
    [viewController addButtonWithTitle:buttonTitle completion:viewController.completion];
  }];

  return viewController;
}

-(instancetype)init; {
  self = [super init];
  if(self) {
    self.buttonCallbacks = [NSMapTable strongToWeakObjectsMapTable];
    self.presenter = [SHPresenterBlocks presenterWithName:@"com.SHAlertViewController.presenter"];
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

  }
  return self;
}

-(void)viewDidLoad; {
  [super viewDidLoad];

  UIScrollView * scrollView = [[UIScrollView alloc] init];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView setContentSize:CGSizeMake(320, 2000)];
  scrollView.alwaysBounceVertical = YES;
  scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  scrollView.delegate = self;
  
  [self.view addSubview:scrollView];
  [scrollView addSubview:self.alertView];
  [self.alertView addSubview:self.lblTitle];  
  [self.alertView addSubview:self.lblMessage];
  self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
//  self.alertView.alpha = 0;
  


}
-(void)viewWillAppear:(BOOL)animated; {
  [super viewWillAppear:animated];
  [self.view setNeedsUpdateConstraints];
  
}
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView; {
//  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  
  if(self.isKeyboardVisible) [scrollView setContentOffset:CGPointMake(0, CGRectGetMinY(self.alertView.frame)-20) animated:YES];
//  });

}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset NS_AVAILABLE_IOS(5_0); {
  NSLog(@"%f - %f", velocity.y, scrollView.contentOffset.y);
  if(self.isKeyboardVisible == YES) return;
  

  if(scrollView.contentOffset.y < -50.f && velocity.y < -0.8f)
    [self dismissWithTappedButtonIndex:0 animated:YES];
}

-(void)viewDidAppear:(BOOL)animated; {
  [super viewDidAppear:animated];
  __weak typeof(self) weakSelf = self;
  self.observerToBackground = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    if([weakSelf.delegate respondsToSelector:@selector(alertViewCancel:)])
      [weakSelf.delegate alertViewCancel:(UIAlertView *)weakSelf];
    else
      [weakSelf dismissWithTappedButtonIndex:-1 animated:animated];
  }];
  
  [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    
    UIScrollView * scrollView = self.view.subviews.firstObject;
    [scrollView setContentOffset:CGPointMake(0, CGRectGetMinY(weakSelf.alertView.frame)-20) animated:YES];
    weakSelf.keyboardVisible = YES;
    
    
  }];
  
  
  [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    weakSelf.keyboardVisible = NO;
    
  }];

  

  SHAlertViewControllerAnimationBlock animationBlock = [SHAlertViewControllerManager sharedManager].blocksAnimation[NSStringFromClass([self class])];
  
  animationBlock(self.alertView, YES, ^(){});
  


}

-(void)viewWillDisappear:(BOOL)animated; {
  [super viewWillDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self.observerToBackground];


}



#pragma mark - Layout

-(void)addButtonWithTitle:(NSString *)theButtonTitle
               completion:(SHAlertViewControllerCompletionBlock)theCompletion; {
  NSParameterAssert(theButtonTitle);
  NSParameterAssert(theCompletion);
  
  UIButton * button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setTitle:theButtonTitle forState:UIControlStateNormal];
  [button addTarget:self action:@selector(tappedButton:) forControlEvents:UIControlEventTouchUpInside];
  SHAlertViewControllerCreateButtonBlock contentBlock =[SHAlertViewControllerManager sharedManager].blocksButton[self.alertStyle];
  if(contentBlock) button = (UIButton *)contentBlock(self.numberOfButtons, button);
  NSParameterAssert(button);
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [self.alertView addSubview:button];
  [self.view setNeedsUpdateConstraints];
  [self.buttonCallbacks setObject:theCompletion forKey:button];
}


-(void)tappedButton:(UIButton *)theButton; {
  NSInteger index = [self.buttons indexOfObject:theButton];
  SHAlertViewControllerCompletionBlock  block = [self.buttonCallbacks objectForKey:theButton];
  if(block) block(index);
  [self dismissWithTappedButtonIndex:index animated:YES];
  
}
#pragma mark - Properties

-(void)setTitle:(NSString *)title; {
  [super setTitle:title];
  if([self.lblTitle respondsToSelector:@selector(setAttributedText:)] && title)
    [self setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{NSTextEffectAttributeName : NSTextEffectLetterpressStyle}]];
  else self.lblTitle.text = title;
}

-(void)setMessage:(NSString *)message; {
  _message = message;
  if([self.lblMessage respondsToSelector:@selector(setAttributedText:)] && message)
    [self setAttributedMessage:[[NSAttributedString alloc] initWithString:message attributes:@{NSTextEffectAttributeName : NSTextEffectLetterpressStyle}]];
  else
    self.lblMessage.text = message;
}

-(void)setAttributedMessage:(NSAttributedString *)attributedMessage; {
  _attributedMessage = attributedMessage;
  self.lblMessage.attributedText = attributedMessage;
}

-(void)setAttributedTitle:(NSAttributedString *)attributedTitle; {
  _attributedTitle = attributedTitle;
  self.lblTitle.attributedText = attributedTitle;
}


#pragma mark - Actions
-(void)dismissWithTappedButtonIndex:(NSInteger)theButtonIndex animated:(BOOL)theAnimatedFlag; {
  [self.delegate alertView:(UIAlertView *)self clickedButtonAtIndex:theButtonIndex];
  [self.delegate alertView:(UIAlertView *)self willDismissWithButtonIndex:theButtonIndex];

  __weak typeof(self) weakSelf = self;
  SHAlertViewControllerAnimationBlock animationBlock = [SHAlertViewControllerManager sharedManager].blocksAnimation[NSStringFromClass([self class])];

  animationBlock(self.alertView, NO, ^(){
    [self.presentingViewController dismissViewControllerAnimated:NO completion:^{
      [weakSelf.delegate alertView:(UIAlertView *)weakSelf didDismissWithButtonIndex:theButtonIndex];
    }];
  });
}

-(void)show; {
  __weak typeof(self) weakSelf = self;
  if([self.delegate respondsToSelector:@selector(willPresentAlertView:)])
    [self.delegate willPresentAlertView:(UIAlertView *)self];
  [self.presenter enqueueViewController:self windowLevel:UIWindowLevelAlert animated:NO completion:^(UIViewController *controller) {
    [weakSelf.delegate didPresentAlertView:(UIAlertView *)self];
  }];
}




#pragma mark - Lazy Loading

-(UILabel *)lblTitle; {
  if (_lblTitle == nil) {
    _lblTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    _lblTitle.textAlignment = NSTextAlignmentCenter;
    _lblTitle.numberOfLines = 0;
    SHAlertViewControllerCreateContentHolderBlock contentBlock =[SHAlertViewControllerManager sharedManager].blocksContent[self.alertStyle];
    _lblTitle = (id)contentBlock(0,_lblTitle);
    NSParameterAssert(_lblTitle);
    _lblTitle.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return _lblTitle;
}

-(UILabel *)lblMessage; {
  if (_lblMessage == nil) {
    _lblMessage = [[UILabel alloc] initWithFrame:CGRectZero];
    _lblMessage.textAlignment = NSTextAlignmentCenter;
    _lblMessage.numberOfLines = 0;
    SHAlertViewControllerCreateContentHolderBlock contentBlock =[SHAlertViewControllerManager sharedManager].blocksContent[self.alertStyle];
    _lblMessage = (id)contentBlock(1,_lblMessage);
    NSParameterAssert(_lblMessage);
    _lblMessage.translatesAutoresizingMaskIntoConstraints = NO;

  }
  return _lblMessage;
}


-(UIView *)alertView; {
  if (_alertView == nil) {
    _alertView = [[UIView alloc] initWithFrame:CGRectZero];
    SHAlertViewControllerCreateAlertBlock contentBlock =[SHAlertViewControllerManager sharedManager].blocksAlert[self.alertStyle];
    if(contentBlock) _alertView = contentBlock(_alertView, &_swipeDirection);
    _alertView.translatesAutoresizingMaskIntoConstraints = NO;
    NSParameterAssert(_alertView);
  }
  return _alertView;
}

-(NSString *)buttonTitleAtIndex:(NSInteger)theButtonIndex; {
  UIButton * button = self.buttons[theButtonIndex];
  return [button titleForState:UIControlStateNormal];
}

-(NSInteger)addButtonWithTitle:(NSString *)title; {
  [self addButtonWithTitle:title completion:self.completion];
  
  return self.numberOfButtons-1;
}

-(void)setSwipeDirection:(SHAlertViewControllerDismissSwipeDirection)theSwipeDirection; {
  _swipeDirection = theSwipeDirection;
}

-(NSArray *)buttons; {
  NSMutableOrderedSet * setOfSubviews = [NSMutableOrderedSet orderedSetWithArray:self.alertView.subviews];
  [setOfSubviews intersectSet:[NSSet setWithArray:self.buttonCallbacks.keyEnumerator.allObjects]];
  return setOfSubviews.array;
}

-(NSInteger)numberOfButtons; {
  return self.buttonCallbacks.count;
}
//@property(nonatomic,readonly) NSInteger firstOtherButtonIndex;
-(BOOL)isVisible; {
  return self.presenter.topViewController == self;
}

+(void)setupInitialStyling; {
  if([SHAlertViewControllerManager sharedManager].blocksButton[NSStringFromClass([self class])] == nil)
    [SHAlertViewController styleAlertButtonBlock:^UIControl *(NSInteger index, UIButton *button) {
      if(index == 0) button.tintColor = [UIColor redColor];
      else  button.tintColor = [UIColor blackColor];
      button.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.2];
      button.titleLabel.font = [UIFont boldSystemFontOfSize:10.f];
      return button;
    }];
  
  if([SHAlertViewControllerManager sharedManager].blocksContent[NSStringFromClass([self class])] == nil)
    [SHAlertViewController styleAlertContentBlock:^id(NSInteger index, UILabel *lblContent) {
      if(index == 0) lblContent.tintColor = [UIColor blackColor];
      else  lblContent.tintColor = [UIColor redColor];
      return lblContent;
    }];
  
  if([SHAlertViewControllerManager sharedManager].blocksAlert[NSStringFromClass([self class])] == nil)
    [SHAlertViewController styleAlertViewBlock:^id(UIView *alertView,SHAlertViewControllerDismissSwipeDirection *dismissDirection) {
      alertView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.9];
      alertView.layer.cornerRadius = 5.0;
      alertView.layer.shadowColor = [UIColor blackColor].CGColor;
      alertView.layer.shadowOpacity = 0.25;
      alertView.layer.shadowRadius = 1;
      alertView.layer.shadowOffset = CGSizeMake(0, 1);
      *dismissDirection = SHAlertViewControllerDismissSwipeDirectionDown;
      return alertView;
    }];
  
  if([SHAlertViewControllerManager sharedManager].blocksAnimation[NSStringFromClass([self class])] == nil)
    [SHAlertViewController styleAlertAnimationBlock:^(UIView *alertView, BOOL isPresenting, SHAlertViewControllerAnimationCompletionBlock completion) {
      
      
      CGAffineTransform fromTransform = CGAffineTransformIdentity;
      if(isPresenting)  fromTransform= CGAffineTransformMakeTranslation(0, CGRectGetHeight([UIScreen mainScreen].bounds)*-1);
      
      CGAffineTransform toTransform = CGAffineTransformMakeTranslation(0, CGRectGetHeight([UIScreen mainScreen].bounds));
      if(isPresenting) toTransform = CGAffineTransformIdentity;
      
      alertView.transform = fromTransform;
      CGFloat damping = 1;
      if(isPresenting)  damping = 0.5;
      [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:damping initialSpringVelocity:1 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState animations:^{
        alertView.layer.affineTransform = toTransform;
      } completion:^(BOOL finished) {
        if(isPresenting) alertView.layer.affineTransform = CGAffineTransformIdentity;
//        else alertView.hidden = YES;
        completion();
      }];
    }];
}

-(void)updateViewConstraints; {
  [self.view removeConstraints:self.view.constraints];
  [self.view.subviews.firstObject removeConstraints:[self.view.subviews.firstObject constraints]];
  [self.alertView removeConstraints:self.alertView.constraints];
  [super updateViewConstraints];

  [self setupLayoutAlert];
  [self setupLayoutTitle];
  [self setupLayoutMessage];
  [self setupLayoutButtons];

  
}

-(void)setupLayoutAlert; {
  UIScrollView * scrollView = self.view.subviews.firstObject;
  
  NSArray * constraint = [[NSLayoutConstraint
                           constraintsWithVisualFormat:@"H:|-(==0)-[scrollView]-(==0)-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(scrollView)]
                            arrayByAddingObjectsFromArray:[NSLayoutConstraint
                                                           constraintsWithVisualFormat:@"V:|-(==0)-[scrollView]-(==0)-|"
                                                                                                   options:kNilOptions
                                                                                                   metrics:nil
                                                                                                     views:NSDictionaryOfVariableBindings(scrollView)
                                                            ]
  ];
  [self.view addConstraints:constraint];
  
  self.centerConstraint = [NSLayoutConstraint constraintWithItem:self.alertView
                                                       attribute:NSLayoutAttributeCenterY
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:self.view.subviews.firstObject
                                                       attribute:NSLayoutAttributeCenterY
                                                      multiplier:1.f constant:0.f];
  [self.view.subviews.firstObject addConstraint:self.centerConstraint];
  
  [self.view.subviews.firstObject addConstraint:
   [NSLayoutConstraint constraintWithItem:self.alertView
                                attribute:NSLayoutAttributeCenterX
                                relatedBy:NSLayoutRelationEqual
                                   toItem:self.view.subviews.firstObject
                                attribute:NSLayoutAttributeCenterX
                               multiplier:1.f constant:0.f]
   ];
  
  
  NSArray * constraintForAlertView = [NSLayoutConstraint
                                      constraintsWithVisualFormat:@"V:|-(>=10)-[_alertView]"
                                      options: kNilOptions
                                      metrics:nil
                                      views:NSDictionaryOfVariableBindings(_alertView)];
  

  constraintForAlertView = [constraintForAlertView arrayByAddingObjectsFromArray:
                            [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_alertView]-|"
                                                                    options: kNilOptions
                                                                    metrics:nil
                                                                      views:NSDictionaryOfVariableBindings(_alertView)]
                            ];
  
  [self.view.subviews.firstObject addConstraints:constraintForAlertView];

}

-(void)setupLayoutTitle; {
  NSNumber * padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingHorizontalTitleToSide];
  NSArray * constraintForTitle = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-padding-[_lblTitle]-padding-|"
                                                                         options:kNilOptions
                                                                         metrics:NSDictionaryOfVariableBindings(padding)
                                                                           views:NSDictionaryOfVariableBindings(_lblTitle)];
  

  padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingTopToNext];
  
  constraintForTitle = [constraintForTitle arrayByAddingObjectsFromArray:
                        [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-padding-[_lblTitle]"
                                                                options:kNilOptions
                                                                metrics:NSDictionaryOfVariableBindings(padding)
                                                                  views:NSDictionaryOfVariableBindings(_lblTitle)]
                        ];
  [self.alertView addConstraints:constraintForTitle];
}

-(void)setupLayoutMessage; {
  NSNumber * padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingHorizontalMessageToSide];
  
  NSArray * constraintForMessage = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_lblMessage]-|"
                                                                           options:kNilOptions
                                                                           metrics:NSDictionaryOfVariableBindings(padding)
                                                                             views:NSDictionaryOfVariableBindings(_lblMessage)];
  
  
  
  padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingTitleToNext];
  NSNumber * paddingEnd = [[self class] paddingForLayoutPaddingType:SHAVCPaddingBottomToPrevious];
  
  if(self.buttons.firstObject)

    constraintForMessage = [constraintForMessage arrayByAddingObjectsFromArray:
                            [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_lblTitle]-padding-[_lblMessage]"
                                                                    options:kNilOptions
                                                                    metrics:NSDictionaryOfVariableBindings(padding)
                                                                      views:NSDictionaryOfVariableBindings(_lblMessage, _lblTitle)]
                            ];
  else
    constraintForMessage = [constraintForMessage arrayByAddingObjectsFromArray:
                            [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_lblTitle]-padding-[_lblMessage]-paddingEnd-|"
                                                                    options:kNilOptions
                                                                    metrics:NSDictionaryOfVariableBindings(padding, paddingEnd)
                                                                      views:NSDictionaryOfVariableBindings(_lblMessage, _lblTitle)]
                            ];
  
  
  
  [self.alertView addConstraints:constraintForMessage];
}

-(void)setupLayoutButtons; {
  [self.buttons enumerateObjectsUsingBlock:^(UIButton * button, NSUInteger idx, __unused BOOL *stop) {
    NSNumber * padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingHorizontalButtonToSide];

    NSArray * constraintForButton = @[];
    
    constraintForButton =  [constraintForButton arrayByAddingObjectsFromArray:
                            [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-padding-[button]-padding-|"
                                                                    options:kNilOptions
                                                                    metrics:NSDictionaryOfVariableBindings(padding)
                                                                      views:NSDictionaryOfVariableBindings(button)]];
    
    if(self.buttons.firstObject == button && self.buttons.lastObject == button) {
      padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingMessageToNext];
      NSNumber * paddingEnd = [[self class] paddingForLayoutPaddingType:SHAVCPaddingBottomToPrevious];
      constraintForButton = [constraintForButton arrayByAddingObjectsFromArray:
                             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_lblMessage]-padding-[button]-paddingEnd-|"
                                                                     options:kNilOptions
                                                                     metrics:NSDictionaryOfVariableBindings(padding, paddingEnd)
                                                                       views:NSDictionaryOfVariableBindings(_lblMessage, button)]
                             ];
    }
    else if(self.buttons.firstObject == button) {
      padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingMessageToNext];
      constraintForButton = [constraintForButton arrayByAddingObjectsFromArray:
                             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_lblMessage]-padding-[button]"
                                                                     options:kNilOptions
                                                                     metrics:NSDictionaryOfVariableBindings(padding)
                                                                       views:NSDictionaryOfVariableBindings(_lblMessage, button)]
                             ];
    }
    
    else if(self.buttons.lastObject == button) {
      UIButton * previousButton = self.buttons[idx-1];
      padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingButtonToNext];
      NSNumber * paddingEnd = [[self class] paddingForLayoutPaddingType:SHAVCPaddingBottomToPrevious];
      constraintForButton = [constraintForButton arrayByAddingObjectsFromArray:
                             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[previousButton]-padding-[button]-paddingEnd-|"
                                                                     options:kNilOptions
                                                                     metrics:NSDictionaryOfVariableBindings(padding,paddingEnd)
                                                                       views:NSDictionaryOfVariableBindings(previousButton,button)]
                             ];
    }
    else {
      UIButton * previousButton = self.buttons[idx-1];
      padding = [[self class] paddingForLayoutPaddingType:SHAVCPaddingButtonToNext];
      constraintForButton = [constraintForButton arrayByAddingObjectsFromArray:
                             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[previousButton]-padding-[button]"
                                                                     options:kNilOptions
                                                                     metrics:NSDictionaryOfVariableBindings(padding)
                                                                       views:NSDictionaryOfVariableBindings(previousButton,button)]
                             ];
    }
    
    
    
    [self.alertView addConstraints:constraintForButton];
    
  }];
}
-(void)dismissWithClickedButtonIndex:(NSInteger)theButtonIndex animated:(BOOL)theAnimatedFlag;  {
  [self dismissWithTappedButtonIndex:theButtonIndex animated:theAnimatedFlag];
}
+(void)styleAlertViewBlock:(SHAlertViewControllerCreateAlertBlock)completionHandler; {
  NSParameterAssert(completionHandler);
  [SHAlertViewControllerManager sharedManager].blocksAlert[NSStringFromClass([self class])] = completionHandler;
}

+(void)styleAlertContentBlock:(SHAlertViewControllerCreateContentHolderBlock)completionHandler; {
  NSParameterAssert(completionHandler);
  [SHAlertViewControllerManager sharedManager].blocksContent[NSStringFromClass([self class])] = completionHandler;
}

+(void)styleAlertButtonBlock:(SHAlertViewControllerCreateButtonBlock)completionHandler; {
  NSParameterAssert(completionHandler);
  [SHAlertViewControllerManager sharedManager].blocksButton[NSStringFromClass([self class])] = completionHandler;
}


+(void)styleAlertAnimationBlock:(SHAlertViewControllerAnimationBlock)theAnimation; {
  NSParameterAssert(theAnimation);
  [SHAlertViewControllerManager sharedManager].blocksAnimation[NSStringFromClass([self class])] = theAnimation;
}


-(NSString *)alertStyle; {
  return NSStringFromClass([self class]);
}

+(void)setLayoutWithPaddingType:(SHAVCPadding)thePaddingType padding:(CGFloat)thePadding; {
  NSMutableDictionary * paddings = [SHAlertViewControllerManager sharedManager].paddingType[NSStringFromClass([self class])];
  if(paddings == nil) paddings = @{}.mutableCopy;
  paddings[@(thePaddingType)] = @(thePadding);
  [[SHAlertViewControllerManager sharedManager].paddingType setObject:paddings forKey:NSStringFromClass([self class])];
}

+(NSNumber *)paddingForLayoutPaddingType:(SHAVCPadding)thePaddingType; {
  NSMutableDictionary * paddings = [SHAlertViewControllerManager sharedManager].paddingType[NSStringFromClass([self class])];
  NSNumber * padding = paddings[@(thePaddingType)];
  if(padding == nil) padding = @(8);
  return padding;

}

@end
