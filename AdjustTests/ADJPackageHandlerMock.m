//
//  ADJPackageHandlerMock.m
//  Adjust
//
//  Created by Pedro Filipe on 10/02/14.
//  Copyright (c) 2014 adjust GmbH. All rights reserved.
//

#import "ADJPackageHandlerMock.h"
#import "ADJLoggerMock.h"
#import "ADJAdjustFactory.h"
#import "ADJActivityHandler.h"

static NSString * const prefix = @"PackageHandler ";

@interface ADJPackageHandlerMock()

@property (nonatomic, strong) ADJLoggerMock *loggerMock;
@property (nonatomic, assign) id<ADJActivityHandler> activityHandler;
@property (nonatomic, assign) BOOL startPaused;

@end

@implementation ADJPackageHandlerMock

- (id)init {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
    return [self initWithActivityHandler:nil startPaused:NO];
#pragma clang diagnostic pop
}
- (id)initWithActivityHandler:(id<ADJActivityHandler>)activityHandler
                  startPaused:(BOOL)startPaused
{
    self = [super init];
    if (self == nil) return nil;

    self.startPaused = startPaused;
    self.activityHandler = activityHandler;

    self.loggerMock = (ADJLoggerMock *) ADJAdjustFactory.logger;
    self.packageQueue = [NSMutableArray array];

    [self.loggerMock test:[prefix stringByAppendingFormat:@"initWithActivityHandler, paused: %d", startPaused]];

    return self;
}

- (void)addPackage:(ADJActivityPackage *)package {
    [self.loggerMock test:[prefix stringByAppendingString:@"addPackage"]];
    [self.packageQueue addObject:package];
}

- (void)sendFirstPackage {
    [self.loggerMock test:[prefix stringByAppendingString:@"sendFirstPackage"]];
}

- (void)sendNextPackage:(ADJResponseData *)responseData {
    [self.loggerMock test:[prefix stringByAppendingString:@"sendNextPackage"]];
}

- (void)closeFirstPackage:(ADJResponseData *)responseData {
    [self.loggerMock test:[prefix stringByAppendingString:@"closeFirstPackage"]];
}

- (void)pauseSending {
    [self.loggerMock test:[prefix stringByAppendingString:@"pauseSending"]];
}

- (void)resumeSending {
    [self.loggerMock test:[prefix stringByAppendingString:@"resumeSending"]];
}

- (void)finishedTracking:(NSDictionary *)jsonDict {
    [self.loggerMock test:[prefix stringByAppendingFormat:@"finishedTracking, %@", jsonDict.descriptionInStringsFileFormat]];
    self.jsonDict = jsonDict;
}

@end
