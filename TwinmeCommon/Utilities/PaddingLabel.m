/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Fabrice Trescartes (Fabrice.Trescartes@twin.life)
 */


#import "PaddingLabel.h"

//
// Interface: PaddingLabel ()
//

@interface PaddingLabel ()

@end

//
// Implementation: PaddingLabel
//

@implementation PaddingLabel

- (void)drawTextInRect:(CGRect)rect {
    
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.insets)];
}

- (CGSize)intrinsicContentSize {
    
    CGSize size = [super intrinsicContentSize];
    
    size.width  += self.insets.left + self.insets.right;
    size.height += self.insets.top + self.insets.bottom;
    
    return size;
}

@end
