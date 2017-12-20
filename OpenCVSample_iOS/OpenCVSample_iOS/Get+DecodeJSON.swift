//
//  Get+DecodeJSON.swift
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/12/4.
//  Copyright © 2017年 Talkit. All rights reserved.
//

import Foundation

func getAndDecodeJSON(_ fileName: String, _ fileType: String) -> Dictionary<String, Any> {
    
    let path = Bundle.main.path(forResource: fileName, ofType: fileType)
    let url = URL(fileURLWithPath: path!)
    do{
        let data = try Data(contentsOf: url)
        let json: Any = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions.mutableContainers)
        let jsonDic = json as! Dictionary<String,Any>
        if let modelName = jsonDic["modelName"] {
            print(modelName)
        }
        let datalist = jsonDic["faces"] as! Dictionary<String, Any>
        return datalist
        
    }catch let err as Error!{
        print(err)
    }
    return Dictionary<String, Any>()
}
