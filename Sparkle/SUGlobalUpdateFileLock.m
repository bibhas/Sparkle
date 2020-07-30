//
//  SUGlobalUpdateFileLock.m
//  Sparkle
//
//  Created by Bibhas Acharya on 7/12/20.
//  Copyright © 2020 Sparkle Project. All rights reserved.
//

#import "SUGlobalUpdateLock.h"
#import "SULog.h"

#define kLockFilePathPrefix @"/private/var/tmp"
#define kLockFilePattern @"(?<target>[^_]+)_(?<agent>[^_]+).Sparkle.pid"

@implementation SUGlobalUpdateLock

+ (SUGlobalUpdateLock *)sharedLock
{
    static dispatch_once_t once;
    static SUGlobalUpdateLock *sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (BOOL)tryLock
{
    NSString *fileLockPath = [self fileLockPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:kLockFilePathPrefix]) {
        return NO;
    }
    if (![fileManager isWritableFileAtPath:kLockFilePathPrefix]) {
        return NO;
    }
    BOOL (^predicateBlock)(NSString *, NSString *) = ^BOOL (NSString *filename, NSString *agent) {
#pragma unused(filename)
        return ![agent isEqualToString:[self identifier]];
    };
    if ([self countLockFilesForTarget:[self identifier] agent:nil withPredicateBlock:predicateBlock] > 0) {
        // Some other agent beat us to it. A lockfile for this app, created by
        // someone other than us, already exists.
        return NO;
    }
    if ([self countLockFilesForTarget:[self identifier] agent:[self identifier] withPredicateBlock:nil] > 0) {
        // Either there are two instances of this very app running (??) or
        // a previous update cycle didn't unlock at the end (a crash perhaps?).
        // Either ways, we're going to pretend like we acquired the lock.
        return YES;
    }
    if (open(fileLockPath.UTF8String, O_CREAT|O_EXCL, S_IRUSR|S_IWUSR) < 0) {
        NSString *errorString = [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding];
        SULog(SULogLevelError, @"Couldn't acquire global lock. (err = %@)", errorString);
        return NO;
    }
    return YES;
}

- (void)unlock
{
    NSString *fileLockPath = [self fileLockPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:kLockFilePathPrefix]) {
        return;
    }
    if (![fileManager isWritableFileAtPath:kLockFilePathPrefix]) {
        return;
    }
    BOOL (^predicateBlock)(NSString *, NSString *) = ^BOOL (NSString *filename, NSString *agent) {
#pragma unused(filename)
        return [agent isEqualToString:[self identifier]];
    };
    if ([self countLockFilesForTarget:[self identifier] agent:[self identifier] withPredicateBlock:predicateBlock] == 0) {
        return;
    }
    NSError *error = nil;
    [fileManager removeItemAtPath:fileLockPath error:&error];
    if (error != nil) {
        SULog(SULogLevelError, @"Unable to unlock! (%@)", [error localizedDescription]);
    }
}

- (void)forceUnlock
{
    // A lockfile name contains both the target app and the agent holding
    // the lock. A plain unlock only succeeds only if the agent name matches.
    // A forced unlock however only checks for the target apps' name.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:kLockFilePathPrefix]) {
        return;
    }
    if (![fileManager isWritableFileAtPath:kLockFilePathPrefix]) {
        return;
    }
    // Remove all lockfiles for this app regardless of agent
    [self iterateLockFilesForTarget:[self identifier] agent:nil withBlock:^(NSString *filepath, NSString *agent) {
    #pragma unused(agent)
        NSError *error = nil;
        NSString *fileLockPath = [NSString stringWithFormat:@"%@/%@", kLockFilePathPrefix, filepath];
        [fileManager removeItemAtPath:fileLockPath error:&error];
        if (error != nil) {
            SULog(SULogLevelError, @"Unable to delete %@! (%@)", filepath, [error localizedDescription]);
        }
    }];
}

#pragma mark -
#pragma mark Private methods

- (NSString *)identifier
{
    NSString *resp = [[NSBundle mainBundle] bundleIdentifier];
    if (resp == nil) {
        // If there's no bundle identifier, use the executable path
        resp = [[[NSBundle mainBundle] executablePath] stringByReplacingOccurrencesOfString:@"/" withString:@"."];
    }
    return resp;
}

- (NSString *)fileLockPath
{
    NSString *identifier = [self identifier];
    // We're both the target and the agent in this case
    return [self fileLockPathForTargetIdentifier:identifier agentIdentifier:identifier];
}

- (NSString *)fileLockPathForTargetIdentifier:(NSString *)aTargetIdentifier agentIdentifier:(NSString *)aAgentIdentifier
{
    return [NSString stringWithFormat:@"%@/%@_%@.Sparkle.pid", kLockFilePathPrefix, aTargetIdentifier, aAgentIdentifier];
}

- (void)iterateLockFilesForTarget:(NSString *)aTargetIdentifier agent:(NSString *)aAgentIdentifier withBlock:(void(^)(NSString *, NSString *))aBlock
{
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:kLockFilePattern options:0 error:&error];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kLockFilePathPrefix error:nil];
    for (NSString *file in contents) {
        if (![file hasSuffix:@".Sparkle.pid"]) {
            continue;
        }
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:file options:0 range:NSMakeRange(0, [file length])];
        if (matches.count < 1) {
            continue;
        }
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        NSString *targetIdentifier = [file substringWithRange:[match rangeAtIndex:1]];
        NSString *agentIdentifier = [file substringWithRange:[match rangeAtIndex:2]];
        if ([targetIdentifier isEqualToString:aTargetIdentifier]) {
            if (aAgentIdentifier == nil || [agentIdentifier isEqualToString:aAgentIdentifier]) {
                if (aBlock) {
                    aBlock(file, agentIdentifier);
                }
            }
        }
    }
}

- (NSUInteger)countLockFilesForTarget:(NSString *)aTargetIdentifier agent:(NSString *)aAgentIdentifier withPredicateBlock:(BOOL(^)(NSString *, NSString *))aBlock
{
    __block NSUInteger resp = 0;
    [self iterateLockFilesForTarget:aTargetIdentifier agent:aAgentIdentifier withBlock:^(NSString *filepath, NSString *agent) {
        BOOL accept = YES;
        if (aBlock) {
            accept = aBlock(filepath, agent);
        }
        if (accept) {
            resp++;
        }
    }];
    return resp;
}

@end

