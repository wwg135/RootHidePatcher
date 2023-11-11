//
//  Derootifier-Swift-Bridging.h
//  RootHidePatcher
//
//  Created by admin on 4/10/2023.
//

#ifndef Derootifier_Swift_Bridging_h
#define Derootifier_Swift_Bridging_h

#include <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR
#include "stub.h"
#else
#include "roothide.h"
#endif

#import <spawn.h>

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

#endif /* Derootifier_Swift_Bridging_h */
