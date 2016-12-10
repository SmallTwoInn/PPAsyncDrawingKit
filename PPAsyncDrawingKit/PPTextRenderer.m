
//
//  PPTextRenderer.m
//  PPAsyncDrawingKit
//
//  Created by DSKcpp on 2016/10/14.
//  Copyright © 2016年 DSKcpp. All rights reserved.
//

#import "PPTextRenderer.h"
#import "PPTextLayoutLine.h"
#import "PPTextAttachment.h"
#import "NSAttributedString+PPAsyncDrawingKit.h"

@interface PPTextRenderer ()
@property (nonatomic, assign) CGPoint touchesBeginPoint;
@end

@implementation PPTextRenderer
- (instancetype)init
{
    if (self = [super init]) {
        self.heightSensitiveLayout = YES;
    }
    return self;
}

- (PPTextLayout *)textLayout
{
    if (!_textLayout) {
        _textLayout = [[PPTextLayout alloc] init];
    }
    return _textLayout;
}

- (NSAttributedString *)attributedString
{
    return self.textLayout.attributedString;
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
    self.textLayout.attributedString = attributedString;
}

- (void)draw
{
    [self drawInContext:UIGraphicsGetCurrentContext()];
}

- (void)drawInContext:(CGContextRef)context
{
    [self drawInContext:context shouldInterruptBlock:nil];
}

- (void)drawInContext:(CGContextRef)context shouldInterruptBlock:(nullable void (^)(BOOL * _Nonnull))shouldInterruptBlock
{
    [self drawInContext:context visibleRect:CGRectNull placeAttachments:YES shouldInterruptBlock:shouldInterruptBlock];
}

- (void)drawInContext:(CGContextRef)context visibleRect:(CGRect)visibleRect placeAttachments:(BOOL)placeAttachments shouldInterruptBlock:(nullable void (^)(BOOL * _Nonnull))shouldInterruptBlock
{
    if (context) {
        NSAttributedString *attributedString = self.attributedString;
        if (attributedString.length > 0) {
            PPTextLayoutFrame *layoutFrame = self.textLayout.layoutFrame;
            if (layoutFrame) {
                UIOffset offset = [self drawingOffsetWithTextLayout:self.textLayout layoutFrame:layoutFrame];
                PPTextHighlightRange *highlightRange = self.pressingHighlightRange;
                if (highlightRange) {
//                    [self enumerateEnclosingRectsForCharacterRange:activeRange.range usingBlock:^(CGRect rect, BOOL *stop) {
//                        [self drawHighlightedBackgroundForActiveRange:activeRange rect:rect context:context];
//                    }];
                }
            }
            CGContextSaveGState(context);
            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
            CGContextScaleCTM(context, 1.0, -1.0);
            CGContextTranslateCTM(context, 0, -self.textLayout.size.height);
            for (PPTextLayoutLine *line in self.textLayout.layoutFrame.lineFragments) {
                CGPoint position = [self.textLayout convertPointToCoreText:line.baselineOrigin];
                CGFloat y = -self.drawingOrigin.y + position.y;
                CGContextSetTextPosition(context, self.drawingOrigin.x + position.x, y);
                CTLineDraw(line.lineRef, context);
            }
            CGContextRestoreGState(context);
            if (placeAttachments) {
                [self drawAttachmentsWithAttributedString:attributedString layoutFrame:self.textLayout.layoutFrame context:context shouldInterrupt:shouldInterruptBlock];
            }
        }
    }
}

- (void)drawAttachmentsWithAttributedString:(NSAttributedString *)attributedString layoutFrame:(PPTextLayoutFrame *)layoutFrame context:(CGContextRef)context shouldInterrupt:(nullable void (^)(BOOL * _Nonnull))shouldInterruptBlock
{
    CGFloat scale = [UIScreen mainScreen].scale;
    [layoutFrame.lineFragments enumerateObjectsUsingBlock:^(PPTextLayoutLine * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        [line enumerateLayoutRunsUsingBlock:^(NSDictionary *attributes, NSRange range) {
            PPTextAttachment *textAttachment = [attributes objectForKey:PPTextAttachmentAttributeName];
            if (textAttachment) {
                CGPoint origin = [line baselineOriginForCharacterAtIndex:range.location];
                UIEdgeInsets edgeInsets = textAttachment.contentEdgeInsets;
                PPFontMetrics font = textAttachment.fontMetricsForLayout;
                origin.y -= font.ascent;
                origin.x -= edgeInsets.left;
                CGSize size = textAttachment.contentSize;
                CGRect rect = (CGRect){(CGPoint)origin, (CGSize)size};
                UIImage *image = textAttachment.contents;
                if (image) {
                    rect = [self convertRectFromLayout:rect];
                    UIGraphicsPushContext(context);
                    [image drawInRect:rect];
                    UIGraphicsPopContext();
                }
            }
        }];
//        if (shouldInterruptBlock) {
//            shouldInterruptBlock(stop);
//        }
    }];
}

- (void)drawHighlightedBackgroundForActiveRange:(PPTextActiveRange *)activeRange rect:(CGRect)rect context:(CGContextRef)context
{
    CGColorRef color;
    if (self.shadowColor) {
        color = self.shadowColor.CGColor;
    } else {
        color = [UIColor colorWithWhite:0.5f alpha:1.0f].CGColor;
    }
    CGContextSetFillColorWithColor(context, color);
    CGContextBeginPath(context);
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    CGFloat radius = 5.0f;
    CGContextMoveToPoint(context, x + radius, y);
    x += width;
    CGContextAddLineToPoint(context, x + width - radius, y);
    CGContextAddArc(context, x - radius, y + radius, radius,  -0.5 * M_PI, 0.0f, 0);
    y += height;
    CGContextAddLineToPoint(context, x, y);
    CGContextAddArc(context, x - radius, y - radius, radius, 0, 0.5 * M_PI, 0);
    x -= width;
    CGContextAddLineToPoint(context, x + radius, y);
    CGContextAddArc(context, x + radius, y - radius, radius, 0.5 * M_PI, M_PI, 0);
    y -= height;
    CGContextAddLineToPoint(context, x, y);
    CGContextAddArc(context, x + radius, y + radius, radius, M_PI, 1.5 * M_PI, 0);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

- (UIOffset)drawingOffsetWithTextLayout:(PPTextLayout *)textLayout layoutFrame:(id)arg2
{
    return UIOffsetZero;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.eventDelegateContextView) {
        UIView *touchView = self.eventDelegateContextView;
        NSSet<UITouch *> * _touches = [event touchesForView:touchView];
        UITouch *touch = _touches.anyObject;
        CGPoint point = CGPointZero;
        if (touch) {
            point = [touch locationInView:touchView];
        }
        point = [self convertPointToLayout:point];
        PPTextHighlightRange *range = [self rangeInRanges:[self eventDelegateActiveRanges] forLayoutLocation:point];
        if (range) {
            self.pressingHighlightRange = range;
            [touchView setNeedsDisplay];
        }
        self.touchesBeginPoint = point;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.savedPressingActiveRange = nil;
//    PPTextActiveRange *activeRange = self.pressingActiveRange;
//    if (activeRange) {
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [self eventDelegateDidPressActiveRange:activeRange];
//        });
//        self.pressingActiveRange = nil;
//        UIView *view = [self.eventDelegate contextViewForTextRenderer:self];
//        [view setNeedsDisplay];
//    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (CGRect)frame
{
    CGSize size;
    if (self.textLayout) {
        size = self.textLayout.size;
    } else {
        size = CGSizeZero;
    }
    return (CGRect){self.drawingOrigin, size};
}

- (void)setFrame:(CGRect)frame
{
    self.drawingOrigin = frame.origin;
    if (self.textLayout) {
        self.textLayout.size = frame.size;
    } else {
        
    }
}

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)range usingBlock:(void (^)(CGRect , BOOL *))block
{
    if (block) {
        [self.textLayout enumerateEnclosingRectsForCharacterRange:range usingBlock:^(CGRect rect, BOOL * _Nonnull stop) {
            CGRect _rect = [self convertRectFromLayout:rect];
            block(_rect, stop);
        }];
    }
}
@end

@implementation PPTextRenderer (Coordinates)
- (CGPoint)convertPointToLayout:(CGPoint)point
{
    CGPoint drawingOrigin = self.drawingOrigin;
    return CGPointMake(point.x - drawingOrigin.x, point.y - drawingOrigin.y);
}

- (CGPoint)convertPointFromLayout:(CGPoint)point
{
    CGPoint drawingOrigin = self.drawingOrigin;
    return CGPointMake(point.x + drawingOrigin.x, point.y + drawingOrigin.y);
}

- (CGRect)convertRectFromLayout:(CGRect)rect
{
    if (CGRectIsNull(rect)) {
        
    } else {
        rect.origin = [self convertPointFromLayout:rect.origin];
    }
    return rect;
}
@end

@implementation PPTextRenderer (Events)
- (UIView *)eventDelegateContextView
{
    if (_eventDelegate) {
        return [_eventDelegate contextViewForTextRenderer:self];
    }
    return nil;
}

- (NSArray *)eventDelegateActiveRanges
{
    if ([_eventDelegate respondsToSelector:@selector(highlightRangesForTextRenderer:)]) {
        return [_eventDelegate highlightRangesForTextRenderer:self];
    }
    return nil;
}

- (PPTextHighlightRange *)rangeInRanges:(NSArray<PPTextHighlightRange *> *)ranges forLayoutLocation:(CGPoint)location
{
    __block NSRange seleRange;

    [self.attributedString attribute:PPTextHighlightRangeAttributeName atIndex:0 longestEffectiveRange:nil inRange:NSMakeRange(0, 0)];
    __block PPTextHighlightRange *r;
    for (PPTextHighlightRange *range in ranges) {
        if ([_eventDelegate textRenderer:self shouldInteractWithHighlightRange:range]) {
//            [self.textLayout enumerateEnclosingRectsForCharacterRange:range.range usingBlock:^(CGRect rect, BOOL *stop) {
//                if (CGRectContainsPoint(rect, location)) {
//                    r = range;
//                    *stop = YES;
//                }
//            }];
            if (r) {
                return r;
            }
        }
    }
    return nil;
}

- (void)eventDelegateDidPressActiveRange:(PPTextActiveRange *)activeRange
{
    if (_eventDelegate) {
        [_eventDelegate textRenderer:self didPressHighlightRange:activeRange];
    }
}
@end

@implementation PPTextRenderer (Debug)
static BOOL textRendererDebugModeEnabled = NO;
+ (BOOL)debugModeEnabled
{
    return textRendererDebugModeEnabled;
}

+ (void)enableDebugMode
{
    [self setDebugModeEnabled:YES];
}

+ (void)disableDebugMode
{
    [self setDebugModeEnabled:NO];
}

+ (void)setDebugModeEnabled:(BOOL)enabled
{
    textRendererDebugModeEnabled = enabled;
    [self debugModeSetEverythingNeedsDisplay];
    [CATransaction flush];
}

+ (void)debugModeSetEverythingNeedsDisplay
{
    
}

+ (void)debugModeSetEverythingNeedsDisplayForView:(id)view
{
    
}

- (void)debugModeDrawLineFramesWithLayoutFrame:(PPTextLayoutFrame *)layoutFrame context:(CGContextRef)context offset:(UIOffset)offset
{
    if (self.textLayout) {
        
    } else {
        
    }
}

@end

