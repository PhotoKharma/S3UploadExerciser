//
//  UploadingFile.m
//  S3UploadExerciser
//
//  Created by Lee Hasiuk on 10/3/14.
//  Copyright (c) 2014 Idealab. All rights reserved.
//

#import "UploadingFile.h"

@implementation UploadingFile

- (id)initWithName:(NSString *)name length:(NSUInteger)length sequenceId:(NSUInteger)sequenceId
{
    if ((self = [super init]) != nil) {
        _sequenceId = sequenceId;
        _name = name;
        _date = [NSDate date];
        _length = length;
    }
    return self;
}

@end
