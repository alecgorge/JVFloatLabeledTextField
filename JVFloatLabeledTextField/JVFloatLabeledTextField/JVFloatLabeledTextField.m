//
//  JVFloatLabeledTextField.m
//  JVFloatLabeledTextField
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013-2015 Jared Verdi
//  Original Concept by Matt D. Smith
//  http://dribbble.com/shots/1254439--GIF-Mobile-Form-Interaction?list=users
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "JVFloatLabeledTextField.h"
#import "NSString+TextDirectionality.h"

#import <libPhoneNumber-iOS/NBAsYouTypeFormatter.h>

static CGFloat const kFloatingLabelShowAnimationDuration = 0.3f;
static CGFloat const kFloatingLabelHideAnimationDuration = 0.3f;

@interface JVFloatLabeledTextField () <UITextFieldDelegate>

@property (nonatomic, getter=isPhoneModeEnabled) BOOL phoneModeEnabled;
@property (nonatomic) NSString *phoneRegion;
@property (nonatomic) NBAsYouTypeFormatter *phoneFormatter;
@property (nonatomic, weak) id<UITextFieldDelegate> upstreamDelegate;

@end

@implementation JVFloatLabeledTextField
{
    BOOL _isFloatingLabelFontDefault;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _floatingLabel = [UILabel new];
    _floatingLabel.alpha = 0.0f;
    [self addSubview:_floatingLabel];
	
    // some basic default fonts/colors
    _floatingLabelFont = [self defaultFloatingLabelFont];
    _floatingLabel.font = _floatingLabelFont;
    _floatingLabelTextColor = [UIColor grayColor];
    _floatingLabel.textColor = _floatingLabelTextColor;
    _animateEvenIfNotFirstResponder = NO;
    _floatingLabelShowAnimationDuration = kFloatingLabelShowAnimationDuration;
    _floatingLabelHideAnimationDuration = kFloatingLabelHideAnimationDuration;
    [self setFloatingLabelText:self.placeholder];

    _adjustsClearButtonRect = YES;
    _isFloatingLabelFontDefault = YES;
    
    [super setDelegate:self];
}

#pragma mark -

- (void)setDelegate:(id<UITextFieldDelegate>)delegate {
    self.upstreamDelegate = delegate;
}

- (id<UITextFieldDelegate>)delegate {
    return self.upstreamDelegate;
}

- (void)enablePhoneNumberModeForRegion:(NSString *)region {
    self.phoneRegion = region ?: [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    self.phoneFormatter = [NBAsYouTypeFormatter.alloc initWithRegionCode:self.phoneRegion];
    self.phoneModeEnabled = YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]) {
        return [self.upstreamDelegate textFieldShouldBeginEditing:textField];
    }
    else {
        return YES;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldDidBeginEditing:)]) {
        [self.upstreamDelegate textFieldDidBeginEditing:textField];
    }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldShouldEndEditing:)]) {
        return [self.upstreamDelegate textFieldShouldEndEditing:textField];
    }
    else {
        return YES;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldDidEndEditing:)]) {
        [self.upstreamDelegate textFieldDidEndEditing:textField];
    }
}


- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string {
    if (textField != self || !self.isPhoneModeEnabled) {
        if([self.upstreamDelegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            return [self.upstreamDelegate textField:textField
                      shouldChangeCharactersInRange:range
                                  replacementString:string];
        }
        else {
            return YES;
        }
    }
    else {
        BOOL singleInsertAtEnd = (string.length == 1) && (range.location == textField.text.length);
        BOOL singleDeleteFromEnd = (string.length == 0) && (range.length == 1) && (range.location == textField.text.length - 1);
        
        BOOL shouldChange = NO;
        NSString *formattedNumber;
        NSString *prefix;
        NSRange formattedRange;
        NSString *removedCharacter;
        if (singleInsertAtEnd) {
            formattedNumber = [self.phoneFormatter inputDigit:string];
            if ([formattedNumber hasSuffix:string]) {
                formattedRange = [formattedNumber rangeOfString:string options:(NSBackwardsSearch | NSAnchoredSearch)];
                prefix = [formattedNumber stringByReplacingCharactersInRange:formattedRange withString:@""];
                shouldChange = YES;
            }
        }
        else if (singleDeleteFromEnd) {
            formattedNumber = [self.phoneFormatter removeLastDigit];
            removedCharacter = [textField.text substringWithRange:range];
            prefix = [formattedNumber stringByAppendingString:removedCharacter];
            formattedRange = [prefix rangeOfString:removedCharacter options:(NSBackwardsSearch | NSAnchoredSearch)];
            shouldChange = YES;
        }
        
        if (shouldChange) {
            if ([self.upstreamDelegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
                [self assignText:prefix];
                if (![self.upstreamDelegate textField:textField
                        shouldChangeCharactersInRange:formattedRange
                                    replacementString:string]) {
                    
                    // Revert changes
                    if (singleInsertAtEnd) {
                        [self.phoneFormatter removeLastDigit];
                    }
                    else if (singleDeleteFromEnd) {
                        [self.phoneFormatter inputDigit:removedCharacter];
                    }
                }
                else {
                    [self assignText:formattedNumber];
                }
            }
            else {
                [self assignText:formattedNumber];
            }
        }
        return NO;
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldShouldClear:)]) {
        return [self.upstreamDelegate textFieldShouldClear:textField];
    }
    else {
        return YES;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([self.upstreamDelegate respondsToSelector:@selector(textFieldShouldReturn:)]) {
        return [self.upstreamDelegate textFieldShouldReturn:textField];
    }
    else {
        return YES;
    }
}

- (void)checkValidity:(NSString *)number {
    NBPhoneNumberUtil *util = [NBPhoneNumberUtil sharedInstance];
    NBPhoneNumber *phoneNumber = [util parse:number defaultRegion:self.phoneRegion error:nil];
    self.containsValidNumber = [util isValidNumber:phoneNumber];
}

- (void)setText:(NSString *)text {
    if (!self.isPhoneModeEnabled) {
        return [super setText:text];
    }

    [self.phoneFormatter clear];
    
    __block NSString *formattedNumber;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        unichar character = [substring characterAtIndex:substringRange.length - 1];
        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:character]) {
            NSString *digit = [NSString stringWithFormat:@"%C", character];
            formattedNumber = [self.phoneFormatter inputDigit:digit];
        }
    }];
    [self assignText:formattedNumber];
}

- (void)assignText:(NSString *)text {
    super.text = text;
    [self checkValidity:text];
}

- (NSString *)phoneNumberWithFormat:(NBEPhoneNumberFormat)format {
    NBPhoneNumberUtil *util = [NBPhoneNumberUtil sharedInstance];
    
    NSError *error;
    NBPhoneNumber *phoneNumber = [util parse:self.text defaultRegion:self.phoneRegion error:&error];
    
    if (!error) {
        return [util format:phoneNumber numberFormat:format error:&error];
    }
    
    NSLog(@"Error parsing phone number: %@", error);
    
    return nil;
}

#pragma mark -

- (UIFont *)defaultFloatingLabelFont
{
    UIFont *textFieldFont = nil;
    
    if (!textFieldFont && self.attributedPlaceholder && self.attributedPlaceholder.length > 0) {
        textFieldFont = [self.attributedPlaceholder attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    }
    if (!textFieldFont && self.attributedText && self.attributedText.length > 0) {
        textFieldFont = [self.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    }
    if (!textFieldFont) {
        textFieldFont = self.font;
    }
    
    return [UIFont fontWithName:textFieldFont.fontName size:roundf(textFieldFont.pointSize * 0.7f)];
}

- (void)updateDefaultFloatingLabelFont
{
    UIFont *derivedFont = [self defaultFloatingLabelFont];
    
    if (_isFloatingLabelFontDefault) {
        self.floatingLabelFont = derivedFont;
    }
    else {
        // dont apply to the label, just store for future use where floatingLabelFont may be reset to nil
        _floatingLabelFont = derivedFont;
    }
}

- (UIColor *)labelActiveColor
{
    if (_floatingLabelActiveTextColor) {
        return _floatingLabelActiveTextColor;
    }
    else if ([self respondsToSelector:@selector(tintColor)]) {
        return [self performSelector:@selector(tintColor)];
    }
    return [UIColor blueColor];
}

- (void)setFloatingLabelFont:(UIFont *)floatingLabelFont
{
    if (floatingLabelFont != nil) {
        _floatingLabelFont = floatingLabelFont;
    }
    _floatingLabel.font = _floatingLabelFont ? _floatingLabelFont : [self defaultFloatingLabelFont];
    _isFloatingLabelFontDefault = floatingLabelFont == nil;
    [self setFloatingLabelText:self.placeholder];
    [self invalidateIntrinsicContentSize];
}

- (void)showFloatingLabel:(BOOL)animated
{
    void (^showBlock)() = ^{
        _floatingLabel.alpha = 1.0f;
        _floatingLabel.frame = CGRectMake(_floatingLabel.frame.origin.x,
                                          _floatingLabelYPadding,
                                          _floatingLabel.frame.size.width,
                                          _floatingLabel.frame.size.height);
    };
    
    if (animated || 0 != _animateEvenIfNotFirstResponder) {
        [UIView animateWithDuration:_floatingLabelShowAnimationDuration
                              delay:0.0f
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:showBlock
                         completion:nil];
    }
    else {
        showBlock();
    }
}

- (void)hideFloatingLabel:(BOOL)animated
{
    void (^hideBlock)() = ^{
        _floatingLabel.alpha = 0.0f;
        _floatingLabel.frame = CGRectMake(_floatingLabel.frame.origin.x,
                                          _floatingLabel.font.lineHeight + _placeholderYPadding,
                                          _floatingLabel.frame.size.width,
                                          _floatingLabel.frame.size.height);

    };
    
    if (animated || 0 != _animateEvenIfNotFirstResponder) {
        [UIView animateWithDuration:_floatingLabelHideAnimationDuration
                              delay:0.0f
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:hideBlock
                         completion:nil];
    }
    else {
        hideBlock();
    }
}

- (void)setLabelOriginForTextAlignment
{
    CGRect textRect = [self textRectForBounds:self.bounds];
    
    CGFloat originX = textRect.origin.x;
    
    if (self.textAlignment == NSTextAlignmentCenter) {
        originX = textRect.origin.x + (textRect.size.width/2) - (_floatingLabel.frame.size.width/2);
    }
    else if (self.textAlignment == NSTextAlignmentRight) {
        originX = textRect.origin.x + textRect.size.width - _floatingLabel.frame.size.width;
    }
    else if (self.textAlignment == NSTextAlignmentNatural) {
        JVTextDirection baseDirection = [_floatingLabel.text getBaseDirection];
        if (baseDirection == JVTextDirectionRightToLeft) {
            originX = textRect.origin.x + textRect.size.width - _floatingLabel.frame.size.width;
        }
    }
    
    _floatingLabel.frame = CGRectMake(originX + _floatingLabelXPadding, _floatingLabel.frame.origin.y,
                                      _floatingLabel.frame.size.width, _floatingLabel.frame.size.height);
}

- (void)setFloatingLabelText:(NSString *)text
{
    _floatingLabel.text = text;
    [self setNeedsLayout];
}

#pragma mark - UITextField

- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    [self updateDefaultFloatingLabelFont];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [super setAttributedText:attributedText];
    [self updateDefaultFloatingLabelFont];
}

- (CGSize)intrinsicContentSize
{
    CGSize textFieldIntrinsicContentSize = [super intrinsicContentSize];
    [_floatingLabel sizeToFit];
    return CGSizeMake(textFieldIntrinsicContentSize.width,
                      textFieldIntrinsicContentSize.height + _floatingLabelYPadding + _floatingLabel.bounds.size.height);
}

- (void)setPlaceholder:(NSString *)placeholder
{
    [super setPlaceholder:placeholder];
    [self setFloatingLabelText:placeholder];
}

- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder
{
    [super setAttributedPlaceholder:attributedPlaceholder];
    [self setFloatingLabelText:attributedPlaceholder.string];
    [self updateDefaultFloatingLabelFont];
}

- (void)setPlaceholder:(NSString *)placeholder floatingTitle:(NSString *)floatingTitle
{
    [super setPlaceholder:placeholder];
    [self setFloatingLabelText:floatingTitle];
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    CGRect rect = [super textRectForBounds:bounds];
    if ([self.text length] || self.keepBaseline) {
        rect = [self insetRectForBounds:rect];
    }
    return CGRectIntegral(rect);
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    CGRect rect = [super editingRectForBounds:bounds];
    if ([self.text length] || self.keepBaseline) {
        rect = [self insetRectForBounds:rect];
    }
    return CGRectIntegral(rect);
}

- (CGRect)insetRectForBounds:(CGRect)rect {
    CGFloat topInset = ceilf(_floatingLabel.bounds.size.height + _placeholderYPadding);
    topInset = MIN(topInset, [self maxTopInset]);
    return CGRectMake(rect.origin.x, rect.origin.y + topInset / 2.0f, rect.size.width, rect.size.height);
}

- (CGRect)clearButtonRectForBounds:(CGRect)bounds
{
    CGRect rect = [super clearButtonRectForBounds:bounds];
    if (0 != self.adjustsClearButtonRect) {
        if ([self.text length] || self.keepBaseline) {
            CGFloat topInset = ceilf(_floatingLabel.font.lineHeight + _placeholderYPadding);
            topInset = MIN(topInset, [self maxTopInset]);
            rect = CGRectMake(rect.origin.x, rect.origin.y + topInset / 2.0f, rect.size.width, rect.size.height);
        }
    }
    return CGRectIntegral(rect);
}

- (CGFloat)maxTopInset
{
    return MAX(0, floorf(self.bounds.size.height - self.font.lineHeight - 4.0f));
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    [super setTextAlignment:textAlignment];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setLabelOriginForTextAlignment];
    
    CGSize floatingLabelSize = [_floatingLabel sizeThatFits:_floatingLabel.superview.bounds.size];
    
    _floatingLabel.frame = CGRectMake(_floatingLabel.frame.origin.x,
                                      _floatingLabel.frame.origin.y,
                                      floatingLabelSize.width,
                                      floatingLabelSize.height);
    
    BOOL firstResponder = self.isFirstResponder;
    _floatingLabel.textColor = (firstResponder && self.text && self.text.length > 0 ?
                                self.labelActiveColor : self.floatingLabelTextColor);
    if (!self.text || 0 == [self.text length]) {
        [self hideFloatingLabel:firstResponder];
    }
    else {
        [self showFloatingLabel:firstResponder];
    }
}

@end
