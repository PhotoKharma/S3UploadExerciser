//
//  ViewController.m
//  S3UploadExerciser
//
//  Created by Lee Hasiuk on 10/3/14.
//  Copyright (c) 2014 Idealab. All rights reserved.
//

#import <S3.h>
#import "ViewController.h"
#import "UploadingFile.h"
#import "UploadingFileCell.h"

#define kAWSAccountID @"<Your Account ID>"
#define kCognitoPoolID @"<Your Pool ID>"
#define kCognitoRoleUnauth @"<Your Role Unauth>"
#define kBucketName @"<Your Bucket Name>"

#define kPathName @"test/"

#define kMinFileSize 2 * 1024
#define kMaxFileSize 256 * 1024
#define kMaxUploadingFiles 10

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_tableContents;
    NSMutableArray *_tableAdditions;
    NSMutableArray *_tableRemovals;
    NSTimer *_timer;
    NSUInteger _retries;
    BOOL _running;
    NSUInteger _sequenceId;
    NSDate *_startDate;
    NSDate *_endDate;
    unsigned long long _totalBytesUploaded;
    UIBackgroundTaskIdentifier _bgTaskId;
    BOOL _animating;
}

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopButton;

@end

@implementation ViewController

- (void)beginBackgroundTask
{
    if (_bgTaskId == UIBackgroundTaskInvalid) {
        _bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self cancelBackgroundTask];
        }];
    }
}

- (void)cancelBackgroundTask
{
    if (_bgTaskId != UIBackgroundTaskInvalid) {
        UIBackgroundTaskIdentifier taskId = _bgTaskId;
        _bgTaskId = UIBackgroundTaskInvalid;
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    }
}

- (void)authenticateWithAWS
{
    AWSCognitoCredentialsProvider *credentialsProvider = [AWSCognitoCredentialsProvider
                                                          credentialsWithRegionType:AWSRegionUSEast1
                                                          accountId:kAWSAccountID
                                                          identityPoolId:kCognitoPoolID
                                                          unauthRoleArn:kCognitoRoleUnauth
                                                          authRoleArn:nil];
    
    AWSServiceConfiguration *configuration = [AWSServiceConfiguration configurationWithRegion:AWSRegionUSEast1
                                                                          credentialsProvider:credentialsProvider];
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
}

- (void)confirmIsMainThread:(BOOL)isMainThread
{
    NSAssert([NSThread currentThread].isMainThread == isMainThread, isMainThread ? @"Expected to be in main thread." : @"Expected to be in worker thread.");
}

- (void)addRemoval:(UploadingFile *)file
{
    NSUInteger index = [_tableAdditions indexOfObject:file];
    if (index != NSNotFound)
        [_tableAdditions removeObjectAtIndex:index];
    else
        [_tableRemovals addObject:file];
}

- (void)uploadFileWithName:(NSString *)name url:(NSURL *)url uploadInfo:(UploadingFile *)file
{
    AWSS3TransferManagerUploadRequest *request = [[AWSS3TransferManagerUploadRequest alloc] init];
    file.request = request;
    request.bucket = kBucketName;
    request.key = [kPathName stringByAppendingString:name];
    request.body = url;
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    BFTask *uploader = [transferManager upload:request];
    [uploader continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id (BFTask *task) {
        [self confirmIsMainThread:YES];
        NSError *error = task.error;
        BOOL cancelled = task.cancelled || request.cancelled;
        if (!cancelled && error != nil) {
            ++file.retries;
            file.lastError = error;
            ++_retries;
            if (_running)
                [self uploadFileWithName:name url:url uploadInfo:file];
            else
                [self addRemoval:file];
        }
        else {
            if (task.completed && !cancelled)
                _totalBytesUploaded += file.length;
            [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
            [self addRemoval:file];
            if (_running)
                [self uploadRandomizedFile];
        }
        return nil;
    }];
}

- (void)uploadRandomizedFile
{
    NSUInteger length = kMinFileSize + arc4random_uniform(kMaxFileSize - kMinFileSize);
    NSMutableData* data = [NSMutableData dataWithLength:length];
    [[NSInputStream inputStreamWithFileAtPath:@"/dev/urandom"] read:data.mutableBytes maxLength:length];
    NSString *baseFileName = [[NSProcessInfo processInfo].globallyUniqueString stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
    NSString *fileName = [baseFileName stringByAppendingString:@".dat"];
    NSURL *fileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    BOOL written = [data writeToURL:fileUrl atomically:YES];
    NSAssert(written, @"Unable to write temporary file of length %lu.", (unsigned long)length);
    if (written) {
        UploadingFile *uploadInfo = [[UploadingFile alloc] initWithName:fileName length:length sequenceId:++_sequenceId];
        [_tableAdditions addObject:uploadInfo];
        [self uploadFileWithName:fileName url:fileUrl uploadInfo:uploadInfo];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self authenticateWithAWS];
    _bgTaskId = UIBackgroundTaskInvalid;
    _tableContents = [NSMutableArray arrayWithCapacity:kMaxUploadingFiles];
    _tableAdditions = [NSMutableArray arrayWithCapacity:kMaxUploadingFiles];
    _tableRemovals = [NSMutableArray arrayWithCapacity:kMaxUploadingFiles];
}

- (void)refreshTableAnimated:(BOOL)animated
{
    [self confirmIsMainThread:YES];
    if (animated) {
        [[_tableView visibleCells] makeObjectsPerformSelector:@selector(refresh)];
        if (!_animating) {
            NSUInteger removalCount = _tableRemovals.count;
            NSUInteger additionCount = _tableAdditions.count;
            if (removalCount != 0 || additionCount != 0) {
                NSMutableIndexSet *removalIndexes = [NSMutableIndexSet indexSet];
                for (NSUInteger i = 0; i < removalCount; ++i) {
                    NSUInteger index = [_tableContents indexOfObject:_tableRemovals[i]];
                    NSAssert(index != NSNotFound, @"Removal object not found in table data.");
                    [removalIndexes addIndex:index];
                }
                NSMutableArray *deletedRows = [NSMutableArray arrayWithCapacity:removalCount];
                [removalIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
                    [deletedRows addObject:[NSIndexPath indexPathForRow:index inSection:0]];
                }];
                [_tableContents removeObjectsInArray:_tableRemovals];
                [_tableRemovals removeAllObjects];
            
                NSUInteger startAdditionIndex = _tableContents.count;
                NSMutableArray *addedRows = [NSMutableArray arrayWithCapacity:additionCount];
                for (NSUInteger i = 0; i < additionCount; ++i)
                    [addedRows addObject:[NSIndexPath indexPathForRow:startAdditionIndex + i inSection:0]];
                [_tableContents addObjectsFromArray:_tableAdditions];
                [_tableAdditions removeAllObjects];
                
                _animating = YES;
                [CATransaction begin];
                [CATransaction setCompletionBlock:^{
                    _animating = NO;
                }];
                [_tableView beginUpdates];
                if (removalCount != 0)
                    [_tableView deleteRowsAtIndexPaths:deletedRows withRowAnimation:UITableViewRowAnimationRight];
                if (additionCount != 0)
                    [_tableView insertRowsAtIndexPaths:addedRows withRowAnimation:UITableViewRowAnimationLeft];
                [_tableView endUpdates];
                [CATransaction commit];
            }
        }
    }
    else {
        [_tableContents removeObjectsInArray:_tableRemovals];
        [_tableRemovals removeAllObjects];
        [_tableContents addObjectsFromArray:_tableAdditions];
        [_tableAdditions removeAllObjects];
        [_tableView reloadData];
    }
}

- (void)refreshTitleAndButtons
{
    if (!_running && !_startStopButton.enabled && _tableContents.count == 0) {
        _startStopButton.title = @"Start";
        _startStopButton.enabled = YES;
    }
    if (_startDate != nil) {
        if (_running)
            _endDate = [NSDate date];
        NSTimeInterval interval = [_endDate timeIntervalSinceDate:_startDate];
        if (interval != 0) {
            double speed = _totalBytesUploaded / interval;
            NSString *title = [NSString stringWithFormat:@"%llu bytes uploaded at %g bytes/sec", _totalBytesUploaded, speed];
            if (_retries != 0)
                title = [title stringByAppendingFormat:@" with %lu retries", (unsigned long)_retries];
            _titleLabel.text = title;
        }
    }
    else
        _titleLabel.text = _running ? @"Waiting..." : @"Please tap Start button at bottom of screen";
}

- (void)refresh
{
    [self refreshTableAnimated:YES];
    [self refreshTitleAndButtons];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _tableContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UploadingFileCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UploadingFileCell"];
    cell.file = _tableContents[indexPath.row];
    return cell;
}

- (IBAction)doStartStop:(id)sender
{
    if (!_running) {
        [self beginBackgroundTask];
        _startDate = [NSDate date];
        _endDate = nil;
        _totalBytesUploaded = 0;
        _sequenceId = 0;
        _retries = 0;
        _running = YES;
        _startStopButton.title = @"Stop";
        for (NSUInteger i = 0; i < kMaxUploadingFiles; ++i)
            [self uploadRandomizedFile];
        [self refresh];
    }
    else {
        [self cancelBackgroundTask];
        _running = NO;
        _startStopButton.enabled = NO;
        for (UploadingFile *file in _tableContents)
            [file.request cancel];
        for (UploadingFile *file in _tableAdditions)
            [file.request cancel];
    }
}

@end
