//
//  ADJRequestHandlerMock.h
//  adjust GmbH
//
//  Created by Pedro Filipe on 10/02/14.
//  Copyright (c) 2014-2015 adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADJRequestHandler.h"

@interface ADJRequestHandlerMock : NSObject <ADJRequestHandler>

@property (nonatomic, assign) BOOL connectionError;

@end
