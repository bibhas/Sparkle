//
//  SUProbeInstallStatus.h
//  Sparkle
//
//  Created by Mayur Pawashe on 3/20/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SUInstallationInfo;

@interface SUProbeInstallStatus : NSObject

+ (void)probeInstallerInProgressForHostBundleIdentifier:(NSString *)hostBundleIdentifier completion:(void (^)(BOOL))completionHandler;

// completionHandler may not be sent on main queue
// additionally, it may be possible that the installer is in progress but we get a nil installation info back
+ (void)probeInstallerUpdateItemForHostBundleIdentifier:(NSString *)hostBundleIdentifier completion:(void (^)(SUInstallationInfo  * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END