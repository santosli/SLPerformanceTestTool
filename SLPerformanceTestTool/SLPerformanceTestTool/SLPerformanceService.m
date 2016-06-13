//
//  SLPerformanceService.m
//  SLPerformanceTestTool
//
//  Created by Santos on 6/6/16.
//  Copyright © 2016 alibaba. All rights reserved.
//

#import "SLPerformanceService.h"
#import <mach/mach.h>

@interface SLPerformanceService ()

@property (nonatomic, assign) double baseMemoryUsed;
@property (nonatomic, strong)NSMutableDictionary *timerContainer;

@end

@implementation SLPerformanceService


+ (instancetype)shareInstance {
    static SLPerformanceService *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[SLPerformanceService alloc] init];
    });
    
    return service;
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _CPUDataArray = [NSMutableArray array];
        _MemDataArray = [NSMutableArray array];
        _timerContainer = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)cleanData {
    [self stopRecorder];
    
    [_CPUDataArray removeAllObjects];
    [_MemDataArray removeAllObjects];
}

- (void)startRecorder {
    //clean old data
    [self cleanData];
    
    //memory baseline
    _baseMemoryUsed = usedMemory();
    
    [self scheduleDispatchTimerWithName:@"recorder" timeInterval:1 queue:nil repeats:YES action:^{
        [self recordCPUData];
        [self recordMemData];
    }];
}

- (void)stopRecorder {
    [self cancelTimerWithName:@"recorder"];
}

- (void)recordCPUData {
    float cpuUsage = [self cpuUsage];
    
    [_CPUDataArray addObject:[NSNumber numberWithFloat:cpuUsage]];
}

- (void)recordMemData {
    double memUsed = ((usedMemory() - _baseMemoryUsed) / 1024.0 / 1024.0);
    
    [_MemDataArray addObject:[NSNumber numberWithDouble:memUsed]];
}


// Application CPU Usage
- (float)cpuUsage {
    @try {
        kern_return_t kr;
        task_info_data_t tinfo;
        mach_msg_type_number_t task_info_count;
        
        task_info_count = TASK_INFO_MAX;
        kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        task_basic_info_t      basic_info;
        thread_array_t         thread_list;
        mach_msg_type_number_t thread_count;
        
        thread_info_data_t     thinfo;
        mach_msg_type_number_t thread_info_count;
        
        thread_basic_info_t basic_info_th;
        uint32_t stat_thread = 0; // Mach threads
        
        basic_info = (task_basic_info_t)tinfo;
        
        // get threads in the task
        kr = task_threads(mach_task_self(), &thread_list, &thread_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        if (thread_count > 0)
            stat_thread += thread_count;
        
        long tot_sec = 0;
        long tot_usec = 0;
        float tot_cpu = 0;
        int j;
        
        for (j = 0; j < thread_count; j++)
        {
            thread_info_count = THREAD_INFO_MAX;
            kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                             (thread_info_t)thinfo, &thread_info_count);
            if (kr != KERN_SUCCESS) {
                return -1;
            }
            
            basic_info_th = (thread_basic_info_t)thinfo;
            
            if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
                tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
                tot_usec = tot_usec + basic_info_th->system_time.microseconds + basic_info_th->system_time.microseconds;
                tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
            }
            
        } // for each thread
        
        kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
        assert(kr == KERN_SUCCESS);
        
        return tot_cpu;
    }
    @catch (NSException *exception) {
        // Error
        return -1;
    }
}

vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}


- (void)scheduleDispatchTimerWithName:(NSString *)timerName
                         timeInterval:(double)interval
                                queue:(dispatch_queue_t)queue
                              repeats:(BOOL)repeats
                               action:(dispatch_block_t)action {
    if (nil == timerName || interval <= 0.0) {
        return;
    }
    
    if (nil == queue) {
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    dispatch_source_t timer = [self.timerContainer objectForKey:timerName];
    if(!timer) {
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_resume(timer);
        [self.timerContainer setObject:timer forKey:timerName];
    }
    
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), interval * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        action();
        
        if (!repeats) {
            [weakSelf cancelTimerWithName:timerName];
        }
    });
}

- (void)cancelTimerWithName:(NSString *)timerName {
    dispatch_source_t timer = [self.timerContainer objectForKey:timerName];
    
    if (!timer) {
        return;
    }
    
    [self.timerContainer removeObjectForKey:timerName];
    dispatch_source_cancel(timer);
}

@end
