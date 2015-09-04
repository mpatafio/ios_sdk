//
//  ADJUtil.m
//  Adjust
//
//  Created by Christian Wellenbrock on 2013-07-05.
//  Copyright (c) 2013 adjust GmbH. All rights reserved.
//

#import "ADJUtil.h"
#import "ADJLogger.h"
#import "UIDevice+ADJAdditions.h"
#import "ADJAdjustFactory.h"
#import "NSString+ADJAdditions.h"
#import "ADJAdjustFactory.h"

#include <sys/xattr.h>

static NSString * const kBaseUrl   = @"https://app.adjust.com";
static NSString * const kClientSdk = @"ios4.2.8";

static NSString * const kDateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'Z";
static NSDateFormatter *dateFormat;

#pragma mark -
@implementation ADJUtil

+ (void) initialize {
    dateFormat = [[NSDateFormatter alloc] init];
    dateFormat.calendar = [NSCalendar calendarWithIdentifier:NSGregorianCalendar];
    dateFormat.locale = [NSLocale systemLocale];
    [dateFormat setDateFormat:kDateFormat];
}

+ (NSString *)baseUrl {
    return kBaseUrl;
}

+ (NSString *)clientSdk {
    return kClientSdk;
}

// inspired by https://gist.github.com/kevinbarrett/2002382
+ (void)excludeFromBackup:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    const char* filePath = [[url path] fileSystemRepresentation];
    const char* attrName = "com.apple.MobileBackup";
    id<ADJLogger> logger = ADJAdjustFactory.logger;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    if (&NSURLIsExcludedFromBackupKey == nil) {
        u_int8_t attrValue = 1;
        int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        if (result != 0) {
            [logger debug:@"Failed to exclude '%@' from backup", url.lastPathComponent];
        }
    } else { // iOS 5.0 and higher
        // First try and remove the extended attribute if it is present
        ssize_t result = getxattr(filePath, attrName, NULL, sizeof(u_int8_t), 0, 0);
        if (result != -1) {
            // The attribute exists, we need to remove it
            int removeResult = removexattr(filePath, attrName, 0);
            if (removeResult == 0) {
                [logger debug:@"Removed extended attribute on file '%@'", url];
            }
        }

        // Set the new key
        NSError *error = nil;
        BOOL success = [url setResourceValue:[NSNumber numberWithBool:YES]
                                      forKey:NSURLIsExcludedFromBackupKey
                                       error:&error];
        if (!success || error != nil) {
            [logger debug:@"Failed to exclude '%@' from backup (%@)", url.lastPathComponent, error.localizedDescription];
        }
    }
#pragma clang diagnostic pop
#pragma clang diagnostic pop

}

+ (NSString *)formatSeconds1970:(double) value {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:value];

    return [self formatDate:date];
}


+ (NSString *)formatDate:(NSDate *) value {
    return [dateFormat stringFromDate:value];
}


+ (NSDictionary *)buildJsonDict:(NSData *)jsonData {
    if (jsonData == nil) {
        return nil;
    }
    NSError *error = nil;
    NSDictionary *jsonDict = nil;
    @try {
        jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    } @catch (NSException *ex) {
        [ADJAdjustFactory.logger error:@"Failed to parse json response. (%@)", ex.description];
        return nil;
    }

    if (error != nil) {
        [ADJAdjustFactory.logger error:@"Failed to parse json response. (%@)", error.localizedDescription];
        return nil;
    }

    return jsonDict;
}

+ (NSString *)getFullFilename:(NSString *) baseFilename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *filename = [path stringByAppendingPathComponent:baseFilename];
    return filename;
}

+ (id)readObject:(NSString *)filename
      objectName:(NSString *)objectName
           class:(Class) classToRead
{
    id<ADJLogger> logger = [ADJAdjustFactory logger];
    @try {
        NSString *fullFilename = [ADJUtil getFullFilename:filename];
        id object = [NSKeyedUnarchiver unarchiveObjectWithFile:fullFilename];
        if ([object isKindOfClass:classToRead]) {
            [logger debug:@"Read %@: %@", objectName, object];
            return object;
        } else if (object == nil) {
            [logger verbose:@"%@ file not found", objectName];
        } else {
            [logger error:@"Failed to read %@ file", objectName];
        }
    } @catch (NSException *ex ) {
        [logger error:@"Failed to read %@ file (%@)", objectName, ex];
    }

    return nil;
}

+ (void)writeObject:(id)object
           filename:(NSString *)filename
         objectName:(NSString *)objectName {
    id<ADJLogger> logger = [ADJAdjustFactory logger];
    NSString *fullFilename = [ADJUtil getFullFilename:filename];
    BOOL result = [NSKeyedArchiver archiveRootObject:object toFile:fullFilename];
    if (result == YES) {
        [ADJUtil excludeFromBackup:fullFilename];
        [logger debug:@"Wrote %@: %@", objectName, object];
    } else {
        [logger error:@"Failed to write %@ file", objectName];
    }
}

+ (NSString *) queryString:(NSDictionary *)parameters {
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in parameters) {
        NSString *value = [parameters objectForKey:key];
        NSString *escapedValue = [value adjUrlEncode];
        NSString *escapedKey = [key adjUrlEncode];
        NSString *pair = [NSString stringWithFormat:@"%@=%@", escapedKey, escapedValue];
        [pairs addObject:pair];
    }

    double now = [NSDate.date timeIntervalSince1970];
    NSString *dateString = [ADJUtil formatSeconds1970:now];
    NSString *escapedDate = [dateString adjUrlEncode];
    NSString *sentAtPair = [NSString stringWithFormat:@"%@=%@", @"sent_at", escapedDate];

    [pairs addObject:sentAtPair];

    NSString *queryString = [pairs componentsJoinedByString:@"&"];
    
    return queryString;
}

+ (BOOL)isNull:(id)value {
    return value == nil || value == (id)[NSNull null];
}

+ (NSString *)formatErrorMessage:(NSString *)prefixErrorMessage
              systemErrorMessage:(NSString *)systemErrorMessage
              suffixErrorMessage:(NSString *)suffixErrorMessage
{
    NSString * errorMessage = [NSString stringWithFormat:@"%@ (%@)", prefixErrorMessage, systemErrorMessage];
    if (suffixErrorMessage == nil) {
        return errorMessage;
    } else {
        return [errorMessage stringByAppendingFormat:@" %@", suffixErrorMessage];
    }
}

+ (NSDictionary *)completedRequest:(NSData *)responseData
                        statusCode:(NSInteger)statusCode
                prefixErrorMessage:(NSString *)prefixErrorMessage
                suffixErrorMessage:(NSString *)suffixErrorMessage
{

    NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] adjTrim];

    [ADJAdjustFactory.logger verbose:@"Response: %@", responseString];

    NSDictionary *jsonDict = [ADJUtil buildJsonDict:responseData];

    if ([ADJUtil isNull:jsonDict]) {
        return nil;
    }

    NSString* messageResponse = [jsonDict objectForKey:@"message"];

    if (messageResponse == nil) {
        messageResponse = @"No message found";
    }

    if (statusCode == 200) {
        [ADJAdjustFactory.logger info:@"%@", messageResponse];
    } else {
        [ADJAdjustFactory.logger error:@"%@", messageResponse];
    }
    
    return jsonDict;
}

+ (void)sendRequest:(NSMutableURLRequest *)request
   prefixErrorMessage:(NSString *)prefixErrorMessage
  jsonResponseHandler:(void (^) (NSDictionary * jsonDict))jsonResponseHandler
{
    [ADJUtil sendRequest:request
      prefixErrorMessage:prefixErrorMessage
      suffixErrorMessage:nil
     jsonResponseHandler:jsonResponseHandler];
}

+ (void)sendRequest:(NSMutableURLRequest *)request
                 prefixErrorMessage:(NSString *)prefixErrorMessage
           suffixErrorMessage:(NSString *)suffixErrorMessage
                jsonResponseHandler:(void (^) (NSDictionary * jsonDict))jsonResponseHandler
{
    //[NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&responseError];
    //@autoreleasepool {

        SEL sendSRSelector = NSSelectorFromString(@"sendSynchronousRequest:returningResponse:error:");
        if (![NSURLConnection respondsToSelector:sendSRSelector]) {
            [ADJAdjustFactory.logger error:@"NSURLConnectionClass respondsToSelector sendSynchronousRequestSelector nil"];
            jsonResponseHandler(nil);
            return;
        }

        NSMethodSignature * sendSRMethodSignature = [NSURLConnection methodSignatureForSelector:sendSRSelector];

        if (sendSRMethodSignature == nil) {
            [ADJAdjustFactory.logger error:@"sendSynchronousRequestMethodSignature nil"];
            jsonResponseHandler(nil);
            return;
        }

        NSInvocation * sendSRInvocation = [NSInvocation invocationWithMethodSignature:sendSRMethodSignature];
        if (sendSRInvocation == nil) {
            [ADJAdjustFactory.logger error:@"sendSRInvocation nil"];
            jsonResponseHandler(nil);
            return;
        }

        [sendSRInvocation setSelector:sendSRSelector];
        [sendSRInvocation setTarget:[NSURLConnection class]];

        NSError __autoreleasing * responseError;
        NSError * __autoreleasing * responseErrorPtr = &responseError;

        NSHTTPURLResponse __autoreleasing * urlResponse;
        NSHTTPURLResponse * __autoreleasing * urlResponsePtr = &urlResponse;

        [sendSRInvocation setArgument:&request atIndex:2];
        [sendSRInvocation setArgument:&urlResponsePtr atIndex:3];
        [sendSRInvocation setArgument:&responseErrorPtr atIndex:4];

        [sendSRInvocation invoke];

        NSData *responseData;

        [sendSRInvocation getReturnValue:&responseData];

        // connection error
        if (responseError != nil) {
            [ADJAdjustFactory.logger error:[ADJUtil formatErrorMessage:prefixErrorMessage
                                                    systemErrorMessage:responseError.localizedDescription
                                                    suffixErrorMessage:suffixErrorMessage]];
            jsonResponseHandler(nil);
            return;
        }
        if ([ADJUtil isNull:responseData]) {
            [ADJAdjustFactory.logger error:[ADJUtil formatErrorMessage:prefixErrorMessage
                                                    systemErrorMessage:@"empty error"
                                                    suffixErrorMessage:suffixErrorMessage]];
            jsonResponseHandler(nil);
            return;
        }

        NSInteger statusCode = urlResponse.statusCode;

        NSDictionary * jsonDict = [ADJUtil completedRequest:responseData
                                                 statusCode:statusCode
                                         prefixErrorMessage:prefixErrorMessage
                                         suffixErrorMessage:suffixErrorMessage];
        jsonResponseHandler(jsonDict);
    //}
}
@end
