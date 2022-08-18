//
//  ShareViewController.m
//  shareSheet
//
//  Created by Anurodh Pokharel on 9/10/18.
//  Copyright © 2018 Monal.im. All rights reserved.
//

#import "ShareViewController.h"
#import "MLSelectionController.h"

#import "UIColor+Theme.h"
#import "MLContact.h"
#import "MLConstants.h"
#import "HelperTools.h"
#import "DataLayer.h"
#import "MLFiletransfer.h"

#import <MapKit/MapKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

@import Intents;

@interface ShareViewController ()

@property (nonatomic, strong) NSArray<NSDictionary*>* accounts;
@property (nonatomic, strong) NSArray<MLContact*>* recipients;
@property (nonatomic, strong) MLContact* recipient;
@property (nonatomic, strong) NSDictionary* account;
@property (nonatomic, strong) MLContact* intentContact;

@end

//TODO: use this approach, but with swiftui: https://diamantidis.github.io/2020/01/11/share-extension-custom-ui
@implementation ShareViewController

+(void) initialize
{
    [HelperTools configureLogging];
    
    //log unhandled exceptions
    NSSetUncaughtExceptionHandler(&logException);
    
    DDLogInfo(@"Initialized ShareViewController");
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    [self.navigationController.navigationBar setBackgroundColor:[UIColor monaldarkGreen]];
    self.navigationController.navigationItem.title = NSLocalizedString(@"Monal", @"");
    
    if(self.extensionContext.intent != nil && [self.extensionContext.intent isKindOfClass:[INSendMessageIntent class]])
    {
        INSendMessageIntent* intent = (INSendMessageIntent*)self.extensionContext.intent;
        self.intentContact = [HelperTools unserializeData:[intent.conversationIdentifier dataUsingEncoding:NSISOLatin1StringEncoding]];
    }
}

- (void) presentationAnimationDidFinish
{
    // list all contacts, not only active chats
    // that will clutter the list of selectable contacts, but you can always use sirikit interactions
    // to get the recently used contacts listed
    NSMutableArray<MLContact*>* recipients = [[DataLayer sharedInstance] contactList];
    
    self.recipients = recipients;
    self.accounts = [[DataLayer sharedInstance] enabledAccountList];

    if(self.intentContact != nil)
    {
        //check if intentContact is in enabled account list
        for(NSDictionary* accountToCheck in self.accounts)
        {
            NSNumber* accountNo = [accountToCheck objectForKey:@"account_id"];
            if(accountNo.intValue == self.intentContact.accountId.intValue)
            {
                self.recipient = self.intentContact;
                self.account = accountToCheck;
                break;
            }
        }
    }
    
    //no intent given or intent contact not found --> select initial recipient (contact with most recent interaction)
    if(!self.account || !self.recipient)
    {
        BOOL recipientFound = NO;
        for(MLContact* recipient in self.recipients)
        {
            for(NSDictionary* accountToCheck in self.accounts)
            {
                NSNumber* accountNo = [accountToCheck objectForKey:@"account_id"];
                if(accountNo.intValue == recipient.accountId.intValue)
                {
                    self.recipient = recipient;
                    self.account = accountToCheck;
                    recipientFound = YES;
                    break;
                }
                if(recipientFound == YES)
                    break;
            }
        }
    }
    
    [self reloadConfigurationItems];
}

-(MLContact* _Nullable) getLastContactForAccount:(NSNumber*) accountNo
{
    for(MLContact* recipient in self.recipients) {
        if(recipient.accountId.intValue == accountNo.intValue) {
            return recipient;
        }
    }
    return nil;
}

-(BOOL) isContentValid
{
    if(self.recipient != nil && self.account != nil)
        return YES;
    return NO;
}

-(void) didSelectPost
{
    NSExtensionItem* item = self.extensionContext.inputItems.firstObject;
    DDLogVerbose(@"Attachments = %@", item.attachments);

    NSItemProvider* provider;
    for(int try=0; try<2 && provider==nil; try++)
    {
        for(NSItemProvider* attachment in item.attachments)
        {
            //only ignore on try #0
            if(try == 0 && ([attachment hasItemConformingToTypeIdentifier:(NSString*)kUTTypePlainText] && self.contentText && ![self.contentText isEqualToString:@""]))
                ;   //ignore plaintext, already displayed in contentText (e.g. comment)
            else if(provider == nil)
                provider = attachment;
            else
            {
                DDLogError(@"We currently are only able to handle exactly one shared item, ignoring this multi-item share!");
                UIAlertController* multiItemWarning = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Multi-item share detected", @"")
                                                                            message:NSLocalizedString(@"We currently are only able to handle exactly one shared item, ignoring this multi-item share!", @"") preferredStyle:UIAlertControllerStyleAlert];
                [multiItemWarning addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Abort", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    [multiItemWarning dismissViewControllerAnimated:YES completion:nil];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                }]];
                [self presentViewController:multiItemWarning animated:YES completion:nil];
                return;
            }
        }
    }
    MLAssert(provider != nil, @"provider should never be nil!");
    
    [HelperTools handleUploadItemProvider:provider withCompletionHandler:^(NSMutableDictionary* payload) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(payload == nil || payload[@"error"] != nil)
            {
                DDLogError(@"Could not save payload for sending: %@", payload[@"error"]);
                NSString* message = NSLocalizedString(@"Monal was not able to send your attachment!", @"");
                if(payload[@"error"] != nil)
                    message = [NSString stringWithFormat:NSLocalizedString(@"Monal was not able to send your attachment: %@", @""), [payload[@"error"] localizedDescription]];
                UIAlertController* unknownItemWarning = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Could not send", @"")
                                                                            message:message preferredStyle:UIAlertControllerStyleAlert];
                [unknownItemWarning addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Abort", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    [unknownItemWarning dismissViewControllerAnimated:YES completion:nil];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                }]];
                [self presentViewController:unknownItemWarning animated:YES completion:nil];
                return;
            }
            
            payload[@"account_id"] = self.recipient.accountId;
            payload[@"recipient"] = self.recipient.contactJid;
            payload[@"comment"] = self.contentText;
            //don't use the comment field for text shares (they already contain the comment text as shared item)
            if([provider hasItemConformingToTypeIdentifier:(NSString*)kUTTypePlainText])
                payload[@"comment"] = @"";
            [self savePayloadMsgAndComplete:payload];
        });
    }];
}

-(void) savePayloadMsgAndComplete:(NSDictionary*) payload
{
    DDLogDebug(@"Saving payload dictionary to outbox: %@", payload);
    [[DataLayer sharedInstance] addShareSheetPayload:payload];
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired __unused) {
        [self openMainApp:payload[@"recipient"]];
    }];
}

-(NSArray*) configurationItems
{
    NSMutableArray* toreturn = [[NSMutableArray alloc] init];
    if(self.accounts.count > 1)
    {
        SLComposeSheetConfigurationItem* accountSelector = [[SLComposeSheetConfigurationItem alloc] init];
        accountSelector.title = NSLocalizedString(@"Account", @"ShareViewController: Account");

        accountSelector.value = [NSString stringWithFormat:@"%@@%@", [self.account objectForKey:@"username"], [self.account objectForKey:@"domain"]];
        accountSelector.tapHandler = ^{
            UIStoryboard* iosShareStoryboard = [UIStoryboard storyboardWithName:@"iosShare" bundle:nil];
            MLSelectionController* controller = (MLSelectionController*)[iosShareStoryboard instantiateViewControllerWithIdentifier:@"accounts"];
            controller.options = self.accounts;
            controller.completion = ^(NSDictionary* selectedAccount)
            {
                if(selectedAccount != nil) {
                    self.account = selectedAccount;
                }
                else {
                    self.account = self.accounts[0]; // at least one account is present (count > 0)
                }
                self.recipient = [self getLastContactForAccount:[self.account objectForKey:@"account_id"]];
                [self reloadConfigurationItems];
            };
            
            [self pushConfigurationViewController:controller];
        };
        [toreturn addObject:accountSelector];
    }
    
    if(!self.account && self.accounts.count > 0)
        self.account = [self.accounts objectAtIndex:0];

    SLComposeSheetConfigurationItem* recipient = [[SLComposeSheetConfigurationItem alloc] init];
    recipient.title = NSLocalizedString(@"Recipient", @"shareViewController: recipient");
    recipient.value = [NSString stringWithFormat:@"%@ (%@)", self.recipient.contactDisplayName, self.recipient.contactJid];
    recipient.tapHandler = ^{
        UIStoryboard* iosShareStoryboard = [UIStoryboard storyboardWithName:@"iosShare" bundle:nil];
        MLSelectionController* controller = (MLSelectionController *)[iosShareStoryboard instantiateViewControllerWithIdentifier:@"contacts"];

        // Create list of recipients for the selected account
        NSMutableArray<NSDictionary*>* recipientsToShow = [[NSMutableArray alloc] init];
        for (MLContact* contact in self.recipients)
        {
            // only show contacts from the selected account
            NSNumber* accountNo = [self.account objectForKey:@"account_id"];
            if(contact.accountId.intValue == accountNo.intValue)
                [recipientsToShow addObject:@{@"contact": contact}];
        }

        controller.options = recipientsToShow;
        controller.completion = ^(NSDictionary* selectedRecipient) {
            MLContact* contact = [selectedRecipient objectForKey:@"contact"];
            if(contact)
                self.recipient = contact;
            else
                self.recipient = nil;
            [self reloadConfigurationItems];
        };
        
        [self pushConfigurationViewController:controller];
    };
    [toreturn addObject:recipient];
    [self validateContent];
    return toreturn;
}

-(void) openURL:(NSURL*) url
{
    UInt16 iterations = 0;
    SEL openURLSelector = NSSelectorFromString(@"openURL:");
    UIResponder* responder = self;
    while((responder = [responder nextResponder]) != nil && iterations++ < 16)
        if([responder respondsToSelector:openURLSelector] == YES)
        {
            UIApplication* app = (UIApplication*)responder;
            if(app != nil)
            {
                [app performSelector:@selector(openURL:) withObject:url];
                break;
            }
        }
}

-(void) openMainApp:(NSString*) recipient
{
    DDLogInfo(@"Now opening mainapp via %@...", kMonalOpenURL);
    NSURL* mainAppUrl = kMonalOpenURL;
    [self openURL:mainAppUrl];
}

@end
