//
//  UploadingFileCell.m
//  S3UploadExerciser
//
//  Created by Lee Hasiuk on 10/3/14.
//  Copyright (c) 2014 Idealab. All rights reserved.
//

#import "UploadingFileCell.h"
#import "UploadingFile.h"

@interface UploadingFileCell ()

@property (weak, nonatomic) IBOutlet UILabel *sequenceLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *retriesLabel;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;

@end

@implementation UploadingFileCell

- (void)setFile:(UploadingFile *)file
{
    _file = file;
    _sequenceLabel.text = [NSString stringWithFormat:@"File: %lu", (unsigned long)_file.sequenceId];
    _sizeLabel.text = [NSString stringWithFormat:@"Bytes: %lu", (unsigned long)_file.length];
    [self setNeedsLayout];
    [self refresh];
}

- (void)refresh
{
    _timeLabel.text = [NSString stringWithFormat:@"Secs: %lu", (unsigned long)round([[NSDate date] timeIntervalSinceDate:_file.date])];
    _retriesLabel.text = _file.retries != 0 ? [NSString stringWithFormat:@"Retries: %lu", (unsigned long)_file.retries] : nil;
    _errorLabel.text = _file.lastError != nil ? [NSString stringWithFormat:@"Last error: %ld", (long)_file.lastError.code] : nil;

}

@end
