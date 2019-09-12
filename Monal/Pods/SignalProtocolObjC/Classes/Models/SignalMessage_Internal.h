//
//  SignalMessage_Internal.h
//  Pods
//
//  Created by Chris Ballinger on 6/30/16.
//
//

#import "SignalMessage.h"
#include "signal_protocol.h"
NS_ASSUME_NONNULL_BEGIN
@interface SignalMessage ()

@property (nonatomic, readonly) signal_message *signal_message;

@end
NS_ASSUME_NONNULL_END
