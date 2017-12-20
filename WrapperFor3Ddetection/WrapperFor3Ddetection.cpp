//
//  WrapperFor3Ddetection.cpp
//  WrapperFor3Ddetection
//
//  Created by Lei on 4/24/16.
//  Copyright © 2016 Lei. All rights reserved.
//

#include "WrapperFor3Ddetection.hpp"
#include "chilitags.hpp"
#include "opencv2/opencv.hpp"
#include <opencv2/core/core.hpp> // for cv::Mat
#include <opencv2/core/core_c.h> // CV_AA

#include <iostream>


chilitags::Chilitags3D mychilitags3D;
cv::Matx44f projection;
double* ResultArray;


extern "C" {
    //This function is used to initialize the chilitag3d, set up the following parameters
    //inputWidth and inputHeight are used to specify the size of image
    //intrinsicsFilename points out where is the camera calibration matrix
    //configFilename points out where is the tag configuration file
    void InitialChilitag3D(int inputWidth, int inputHeight, char* INPUTintrinsicsFilename, char* INPUTconfigFilename){
        
        //confirm msgs from python
        std::cout << "Address of camera calibration file: " << INPUTintrinsicsFilename << std::endl;
        std::cout << "Address of tag configuration file: " << INPUTconfigFilename << std::endl;
        std::cout << "Camera Width: " << inputWidth << std::endl;
        std::cout << "Camera Height: " << inputHeight << std::endl;
        
        mychilitags3D.readTagConfiguration(INPUTconfigFilename);
        mychilitags3D.readCalibration(INPUTintrinsicsFilename);
        cv::Mat projectionMat = cv::Mat::zeros(4,4,CV_32F);
        mychilitags3D.getCameraMatrix().copyTo(projectionMat(cv::Rect(0,0,3,3)));
        projection = projectionMat;
        projection(3,2) = 1;
        std::cout << "configuration success" << std::endl;
    }
    
    
    //This function is used to get result from a certain image
    //input one image (rows, cols, imgData) and
    //two pointers for sending back information (NameOfObjects, TotalObjects)
    //NameOfObjects is encoded as follows: "name1,name2,name3..."
    //return a double array to specify the transformation matrics
    //ResultArray is encoded as
    // [r11 , r12 , r13 , tx, r21 , r22 , r23 , ty, r31 , r32 , r33 , tz]*TotalObjects
    double* GetResult(int rows, int cols, unsigned char* imgData,char* NameOfObjects, int* TotalObjects){
       
        //form the input image from original data
        cv::Mat img(rows, cols, CV_8UC3, (void*)imgData);
        cv::Mat inputImage = img.clone();
        
        //get data result
        chilitags::TagPoseMap TempResult=mychilitags3D.estimate(inputImage);
        *TotalObjects=int(TempResult.size());
        
        //decode and encode results
        std::string TagName;
        int ArrayCount=0;
        ResultArray= new double[200];
        for (auto& kv : TempResult) {
            
            cv::Matx44f transformation = kv.second;
            
            //get the name
            TagName=TagName+kv.first+',';
            //get the data
            for (int i=0; i<3; i++){
                for (int j=0; j<4; j++){
                    ResultArray[j+i*4+12*ArrayCount]=transformation(i,j);
                }
            }
            //add arraycount
            ArrayCount++;
        }
        std::strcpy(NameOfObjects, TagName.c_str());
        
        return ResultArray;
    }
}

//int cameraIndex, int inputWidth, int inputHeight,