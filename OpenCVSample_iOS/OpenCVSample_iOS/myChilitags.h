//
//  Chilitags.h
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface myChilitags : NSObject

// Converts a full color image to grayscale image with using OpenCV.
//+ (nonnull UIImage *)cvtColorBGR2GRAY:(nonnull UIImage *)image;
// This is the OpenCV sample interface
// We just need to implement new functions here

+ (nonnull UIImage *)detectQRCode:(nonnull UIImage *)image;
+ (nonnull UIImage *)estimate3D:(nonnull UIImage *)image second:(nonnull NSString *)configFilePath;

@end
