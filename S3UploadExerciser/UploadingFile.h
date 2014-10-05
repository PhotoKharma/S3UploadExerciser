//
//  UploadingFile.h
//  S3UploadExerciser
//
//  Created by Lee Hasiuk on 10/3/14.
//  Copyright (c) 2014 Idealab. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AWSS3TransferManagerUploadRequest;

@interface UploadingFile : NSObject

- (id)initWithName:(NSString *)name length:(NSUInteger)length sequenceId:(NSUInteger)sequenceId;

@property (assign, nonatomic, readonly) NSUInteger sequenceId;
@property (strong, nonatomic, readonly) NSString *name;
@property (strong, nonatomic, readonly) NSDate *date;
@property (assign, nonatomic, readonly) NSUInteger length;
@property (strong, nonatomic) AWSS3TransferManagerUploadRequest *request;
@property (assign, nonatomic) NSUInteger retries;
@property (strong, nonatomic) NSError *lastError;

@end
