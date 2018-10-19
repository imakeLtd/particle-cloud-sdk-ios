//
//  ParticleNetwork.m
//  ParticleSDKPods
//
//  Created by Ido Kleinman on 9/24/18.
//  Copyright © 2018 Particle Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ParticleNetwork.h"
#import "ParticleErrorHelper.h"
#import "ParticleCloud.h"
#import <objc/runtime.h>


#ifdef USE_FRAMEWORKS
#import <AFNetworking/AFNetworking.h>
#else
#import "AFNetworking.h"
#endif

@interface ParticleNetwork()
@property (nonatomic, strong) AFHTTPSessionManager *manager;
@property (nonatomic, strong) NSURL *baseURL;
@end


@implementation ParticleNetwork

-(nullable instancetype)initWithParams:(NSDictionary *)params
{
    if (self = [super init])
    {
        _baseURL = [NSURL URLWithString:kParticleAPIBaseURL];
        if (!_baseURL) {
            return nil;
        }
        
        _name = nil;
        if ([params[@"name"] isKindOfClass:[NSString class]])
        {
            _name = params[@"name"];
        }
        
        _id = nil;
        if ([params[@"id"] isKindOfClass:[NSString class]])
        {
            _id = params[@"id"];
        }
        
        _notes = nil;
        if ([params[@"notes"] isKindOfClass:[NSString class]])
        {
            _notes = params[@"notes"];
        }
        
        if ([params[@"type"] isKindOfClass:[NSString class]])
        {
            if ([params[@"type"] isEqualToString:@"micro_wifi"]) {
                _type = ParticleNetworkTypeMicroWifi;
            } else if ([params[@"type"] isEqualToString:@"micro_cellular"]) {
                _type = ParticleNetworkTypeMicroCellular;
            } else if ([params[@"type"] isEqualToString:@"high_availability"]) {
                _type = ParticleNetworkTypeHighAvailability;
            } else if ([params[@"type"] isEqualToString:@"large_site"]) {
                _type = ParticleNetworkTypeLargeSite;
            } else {
                _type = ParticleNetworkTypeMicroWifi;
            }

        }
        
        _gatewayCount = 0;
        if ([params[@"gateway_count"] isKindOfClass:[NSNumber class]])
        {
            _gatewayCount = [params[@"gateway_count"] intValue];
        }
        
        _deviceCount = 0;
        if ([params[@"device_count"] isKindOfClass:[NSNumber class]])
        {
            _deviceCount = [params[@"device_count"] intValue];
        }
        
        _channel = 0;
        if ([params[@"channel"] isKindOfClass:[NSNumber class]])
        {
            _channel = [params[@"channel"] intValue];
        }
        
        // state...
        
        if ([params[@"last_heard"] isKindOfClass:[NSString class]])
        {
            // TODO: add to utils class as POSIX time to NSDate
            NSString *dateString = params[@"last_heard"];// "2015-04-18T08:42:22.127Z"
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
            NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            [formatter setLocale:posix];
            _lastHeard = [formatter dateFromString:dateString];
        }

        self.manager = [[AFHTTPSessionManager alloc] initWithBaseURL:self.baseURL];
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        if (!self.manager) return nil;
        
        return self;
    }
    
    return nil;
}


-(NSURLSessionDataTask *)_takeNetworkAction:(NSString *)action
                                  deviceID:(NSString *)deviceID
                                completion:(nullable ParticleCompletionBlock)completion
{
    // TODO: put /v1/networks
    
    NSMutableDictionary *params = [@{
                                     @"action": action,
                                     @"deviceID": deviceID,
                                     } mutableCopy];
    
    NSString *url = [NSString stringWithFormat:@"/v1/networks/%@", self.id];
    
    NSURLSessionDataTask *task = [self.manager PUT:url parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject)
                                  {
                                      NSDictionary *responseDict = responseObject;
                                      if (completion) {
                                          if ([responseDict[@"ok"] boolValue])
                                          {
                                              completion(nil);
                                          }
                                          else
                                          {
                                              NSString *errorString;
                                              if (responseDict[@"errors"][0])
                                                  errorString = [NSString stringWithFormat:@"Could not modify network: %@",responseDict[@"errors"][0]];
                                              else
                                                  errorString = @"Error modifying network";
                                              
                                              NSError *particleError = [ParticleErrorHelper getParticleError:nil task:task customMessage:errorString];
                                              
                                              completion(particleError);
                                              
                                              NSLog(@"! takeNetworkAction (%@) Failed %@ (%ld): %@\r\n%@", action, task.originalRequest.URL, (long)particleError.code, particleError.localizedDescription, particleError.userInfo[ParticleSDKErrorResponseBodyKey]);
                                          }
                                      }
                                  } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
                                  {
                                      NSError *particleError = [ParticleErrorHelper getParticleError:error task:task customMessage:nil];
                                      
                                      if (completion) {
                                          completion(particleError);
                                      }
                                      
                                      NSLog(@"! takeNetworkAction (%@) Failed %@ (%ld): %@\r\n%@", action, task.originalRequest.URL, (long)particleError.code, particleError.localizedDescription, particleError.userInfo[ParticleSDKErrorResponseBodyKey]);
                                  }];
    
    [self.manager.requestSerializer clearAuthorizationHeader];
    
    return task;
}


-(NSURLSessionDataTask *)addDevice:(NSString *)deviceID
                        completion:(nullable ParticleCompletionBlock)completion
{
    return [self _takeNetworkAction:@"add-device" deviceID:deviceID completion:completion];
    
}

-(NSURLSessionDataTask *)removeDevice:(NSString *)deviceID
                           completion:(nullable ParticleCompletionBlock)completion
{
    return [self _takeNetworkAction:@"remove-device" deviceID:deviceID completion:completion];
    
}

-(NSURLSessionDataTask *)enableGateway:(NSString *)deviceID
                                  completion:(nullable ParticleCompletionBlock)completion
{
    return [self _takeNetworkAction:@"gateway-enable" deviceID:deviceID completion:completion];
}

-(NSURLSessionDataTask *)disableGateway:(NSString *)deviceID
                                   completion:(nullable ParticleCompletionBlock)completion
{
    return [self _takeNetworkAction:@"gateway-disable" deviceID:deviceID completion:completion];
    
}

-(NSURLSessionDataTask *)refresh:(nullable ParticleCompletionBlock)completion
{
    return [[ParticleCloud sharedInstance] getNetwork:self.id completion:^(ParticleNetwork * _Nullable updatedNetwork, NSError * _Nullable error) {
        if (!error)
        {
            if (updatedNetwork)
            {
                // if we got an updated network from the cloud - overwrite ALL self's properies with the new device properties (except for delegate which should be copied over)
                NSMutableSet *propNames = [NSMutableSet set];
                unsigned int outCount, i;
                objc_property_t *properties = class_copyPropertyList([updatedNetwork class], &outCount);
                for (i = 0; i < outCount; i++) {
                    objc_property_t property = properties[i];
                    NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSStringEncodingConversionAllowLossy];
                    [propNames addObject:propertyName];
                }
                free(properties);
                
//                if (self.delegate) {
//                    updatedDevice.delegate = self.delegate;
//                }
                
                for (NSString *property in propNames)
                {
                    id value = [updatedNetwork valueForKey:property];
                    [self setValue:value forKey:property];
                }
            }
            if (completion)
            {
                completion(nil);
            }
        }
        else
        {
            if (completion)
            {
                completion(error);
            }
        }
    }];
    
    return nil;
}



@end
