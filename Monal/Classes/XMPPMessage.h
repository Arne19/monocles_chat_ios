//
//  XMPPMessage.h
//  Monal
//
//  Created by Anurodh Pokharel on 7/13/13.
//
//


#import "MLXMLNode.h"

extern NSString* const kMessageChatType;
extern NSString* const kMessageGroupChatType;
extern NSString* const kMessageErrorType;
extern NSString* const kMessageNormalType;

@interface XMPPMessage : MLXMLNode

/**
 Sets the id attribute of the element
 */
-(void) setXmppId:(NSString*) idval;

/**
 returns value of id attribute if set
 */
-(NSString *) xmppId;

/**
 Sets the body child element
 */
-(void) setBody:(NSString*) messageBody;

/**
 send image uploads out of band 
 */
-(void) setOobUrl:(NSString*) link;


/**
 sets the receipt child element
 */
-(void) setReceipt:(NSString*) messageId;

/**
 Hint saying the message should be stored
 @see https://xmpp.org/extensions/xep-0334.html
 */
-(void) setStoreHint;


@end
