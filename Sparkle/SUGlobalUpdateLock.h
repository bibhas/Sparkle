//
//  SUGlobalUpdateLock.h
//  Sparkle
//
//  Created by Bibhas Acharya on 7/12/20.
//  Copyright © 2020 Sparkle Project. All rights reserved.
//

#ifndef SUGLOBALUPDATELOCK_H
#define SUGLOBALUPDATELOCK_H

#import <Foundation/Foundation.h>

@interface SUGlobalUpdateLock : NSObject
+ (SUGlobalUpdateLock *)sharedLock;
- (BOOL)tryLock;
- (void)unlock;
- (void)forceUnlock;
@end

#endif
