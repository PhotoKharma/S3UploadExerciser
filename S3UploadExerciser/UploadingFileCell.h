//
//  UploadingFileCell.h
//  S3UploadExerciser
//
//  Created by Lee Hasiuk on 10/3/14.
//  Copyright (c) 2014 Idealab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UploadingFile;

@interface UploadingFileCell : UITableViewCell

- (void)refresh;

@property (strong, nonatomic) UploadingFile *file;

@end
