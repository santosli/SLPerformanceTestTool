//
//  SLPerformanceService.h
//  SLPerformanceTestTool
//
//  Created by Santos on 6/6/16.
//  Copyright © 2016 alibaba. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SLPerformanceService : NSObject

@property (nonatomic, strong)NSMutableArray *CPUDataArray;
@property (nonatomic, strong)NSMutableArray *MemDataArray;


+ (instancetype)shareInstance;

- (void)startRecorder;

- (void)stopRecorder;


@end
