//
//  myOpenCV.m
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/22.
//  Copyright © 2017年 Talkit. All rights reserved.
//

// Put OpenCV include files at the top. Otherwise an error happens.
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/core/utility.hpp>
#import <opencv2/core/core_c.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>

#import <Foundation/Foundation.h>
#import <csignal>
#import <iostream>
#import <vector>

// OpenCV.h and Chilitags.h are functions of our own, they are called by ViewController
#import "myOpenCV.h"

//using namespace cv;

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

@implementation myOpenCV

+ (nonnull UIImage *)detectRed:(nonnull UIImage *)image {
    cv::Mat inputImageMat, outputImageMat, imgHSV, imgThresholded;
    UIImage *outputImage;
    
    int iLowH = 170;
    int iHighH = 179;
    
    int iLowS = 150;
    int iHighS = 255;
    
    int iLowV = 60;
    int iHighV = 255;
    
    int iLastX = -1;
    int iLastY = -1;
    
    // OpenCv can draw with sub-pixel precision with fixed point coordinates
    static const int SHIFT = 16;
    static const float PRECISION = 1<<SHIFT;
    
    std::vector<cv::Point> trackingPoints;
    
    UIImageToMat(image, inputImageMat);
    outputImageMat = inputImageMat.clone();
    
    //Create a black image with the size as the camera output
    //cv::Mat imgLines = cv::Mat::zeros( inputImageMat.size(), CV_8UC3 );;
    
    cvtColor(inputImageMat, imgHSV, cv::COLOR_BGR2HSV); //Convert the captured frame from BGR to HSV
    
    cv::inRange(imgHSV, cv::Scalar(iLowH, iLowS, iLowV), cv::Scalar(iHighH, iHighS, iHighV), imgThresholded); //Threshold the image
    
    //morphological opening (removes small objects from the foreground)
    erode(imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
    dilate( imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
    
    //morphological closing (removes small holes from the foreground)
    dilate( imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
    erode(imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
    
    //Calculate the moments of the thresholded image
    cv::Moments oMoments = moments(imgThresholded);
    
    double dM01 = oMoments.m01;
    double dM10 = oMoments.m10;
    double dArea = oMoments.m00;
    
    const static cv::Scalar COLOR(0, 255, 0);
    
    // if the area <= 10000, I consider that the there are no object in the image and it's because of the noise, the area is not zero
    if (dArea > 10000) {
        //calculate the position of the ball
        int posX = dM10 / dArea;
        int posY = dM01 / dArea;
        
        if (iLastX >= 0 && iLastY >= 0 && posX >= 0 && posY >= 0) {
            trackingPoints.push_back(cv::Point(iLastX, iLastY));
            
            std::vector<cv::Point>::iterator it;
            for (it = trackingPoints.begin(); it != trackingPoints.end() - 1; it++) {
                cv::Point tempLastPoint = *it;
                cv::Point tempPoint = *(it + 1);
                line(outputImageMat, PRECISION * tempLastPoint, PRECISION * tempPoint, COLOR, 1, cv::LINE_AA, SHIFT);
            }
            
            //Draw a red line from the previous point to the current point
            line(outputImageMat, PRECISION * cv::Point(posX, posY), PRECISION * cv::Point(iLastX, iLastY), COLOR, 1, cv::LINE_AA, SHIFT);
            
        }
        
        iLastX = posX;
        iLastY = posY;
        //std::cout << iLastX << " " << iLastY << std::endl;
    }
    
    outputImage = MatToUIImage(outputImageMat);
    return RestoreUIImageOrientation(outputImage, image);
}
@end

