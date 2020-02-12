//
//  chat.h
//  SworIM
//
//  Created by Anurodh Pokharel on 1/25/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MLConstants.h"

@interface addContact : UITableViewController <UITextFieldDelegate>
{
    UITextField* _currentTextField;
    NSInteger _selectedRow;
    UIBarButtonItem* _closeButton;
}

@property (nonatomic, weak)  UITextField* contactName;
@property (nonatomic, strong) contactCompletion completion;

-(IBAction) addPress:(id)sender;
-(void) closeView;


@end
