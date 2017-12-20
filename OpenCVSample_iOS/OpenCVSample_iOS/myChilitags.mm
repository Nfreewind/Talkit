//
//  Chilitags.m
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//

// Put OpenCV include files at the top. Otherwise an error happens.
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/core/utility.hpp>
#import <opencv2/core/core_c.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>

// Chilitags header file
#import <chilitags.hpp>

#import <Foundation/Foundation.h>
#import <csignal>
#import <iostream>
#import <vector>

// OpenCV.h and Chilitags.h are functions of our own, they are called by ViewController
#import "myChilitags.h"

/// Converts an UIImage to Mat.
/// Orientation of UIImage will be lost.
static void UIImageToMat(UIImage *image, cv::Mat &mat) {
    
    // Create a pixel buffer.
    NSInteger width = CGImageGetWidth(image.CGImage);
    NSInteger height = CGImageGetHeight(image.CGImage);
    CGImageRef imageRef = image.CGImage;
    cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    // Draw all pixels to the buffer.
    cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
    cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
    
    mat = mat8uc3;
}

/// Converts a Mat to UIImage.
static UIImage *MatToUIImage(cv::Mat &mat) {
    
    // Create a pixel buffer.
    assert(mat.elemSize() == 1 || mat.elemSize() == 3);
    cv::Mat matrgb;
    if (mat.elemSize() == 1) {
        cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
    } else if (mat.elemSize() == 3) {
        cv::cvtColor(mat, matrgb, CV_BGR2RGB);
    }
    
    // Change a image format.
    NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
    CGColorSpaceRef colorSpace;
    if (matrgb.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

/// Restore the orientation to image.
static UIImage *RestoreUIImageOrientation(UIImage *processed, UIImage *original) {
    if (processed.imageOrientation == original.imageOrientation) {
        return processed;
    }
    return [UIImage imageWithCGImage:processed.CGImage scale:1.0 orientation:original.imageOrientation];
}

#pragma mark -

// fulfill the functions of our own using Chilitags or the function above
@implementation myChilitags

+ (nonnull UIImage *)detectQRCode:(nonnull UIImage *)image {
    cv::Mat inputImageMat, outputImageMat;
    UIImage *outputImage;
    chilitags::Chilitags chltgs;
    
    chltgs.setFilter(0, 0.0f);
    UIImageToMat(image, inputImageMat);
    
    int64 startTime = cv::getTickCount();
    // Detect tags on the current image (and time the detection);
    // The resulting map associates tag ids (between 0 and 1023)
    // to four 2D points corresponding to the corners positions
    // in the picture.
    chilitags::TagCornerMap tags = chltgs.find(inputImageMat);

    // Measure the processing time needed for the detection
    int64 endTime = cv::getTickCount();
    
    float processingTime = 1000.0f*((float) endTime - startTime)/cv::getTickFrequency();
    
    // Now we start using the result of the detection.
    
    // First, we set up some constants related to the information overlaid
    // on the captured image
    const static cv::Scalar COLOR(0, 255, 0);
    // OpenCv can draw with sub-pixel precision with fixed point coordinates
    static const int SHIFT = 16;
    static const float PRECISION = 1<<SHIFT;
    
    outputImageMat = inputImageMat.clone();
    
    for (const std::pair<int, chilitags::Quad> & tag : tags) {
        
        int id = tag.first;
        // We wrap the corner matrix into a datastructure that allows an
        // easy access to the coordinates
        const cv::Mat_<cv::Point2f> corners(tag.second);
        
        // We start by drawing the borders of the tag
        for (size_t i = 0; i < 4; ++i) {
            cv::line(
                     outputImageMat,
                     PRECISION*corners(i),
                     PRECISION*corners((i+1)%4),
                     COLOR, 1, cv::LINE_AA, SHIFT);
            
        }
        cv::Point2f center = 0.5f*(corners(0) + corners(2));
        cv::putText(outputImageMat, cv::format("%d", id), center,
                    cv::FONT_HERSHEY_SIMPLEX, 0.5f, COLOR);
        cv::putText(outputImageMat,
                    cv::format("%dx%d %4.0f ms (press q to quit)",
                               outputImageMat.cols, outputImageMat.rows,
                               processingTime),
                    cv::Point(100, 100),
                    cv::FONT_HERSHEY_SIMPLEX, 0.5f, COLOR);\
        std::cout << center.x << " " << center.y << std::endl;
        
    }
    
    // Some stats on the current frame (resolution and processing time)
    /*cv::putText(outputImageMat,
                cv::format("%dx%d %4.0f ms (press q to quit)",
                           outputImageMat.cols, outputImageMat.rows,
                           processingTime),
                cv::Point(32,32),
                cv::FONT_HERSHEY_SIMPLEX, 0.5f, COLOR);*/
    
    outputImage = MatToUIImage(outputImageMat);
    return RestoreUIImageOrientation(outputImage, image);
}

+ (void)estimate3D:(nonnull UIImage *)image second:(nonnull NSString *) configFilePath{
    cv::Mat inputImageMat, outputImageMat;
    UIImageToMat(image, inputImageMat);
    chilitags::Chilitags3D chilitags3D;
    const char * configFile = NULL;
    if ([configFilePath canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        configFile = [configFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    }
    chilitags3D.readTagConfiguration(configFile);
    for (auto& kv : chilitags3D.estimate(inputImageMat)) {
        std::cout << kv.first << " at " << cv::Mat(kv.second) << "\n";
    }
}

@end
