//
//  MLResourcesViewController.m
//  Monal-OSX
//
//  Created by Anurodh Pokharel on 1/10/19.
//  Copyright © 2019 Monal.im. All rights reserved.
//

#import "MLResourcesViewController.h"
#import "MLXMPPManager.h"
#import "MLKeyRow.h"
#import "DataLayer.h"

@interface MLResourcesViewController ()
@property (nonatomic, weak) xmpp *account;
@property (nonatomic, strong) NSArray *resources;
@end

@implementation MLResourcesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


-(void)viewWillAppear
{
    [super viewWillAppear];

    self.view.window.title=@"Resources";
    
    self.account=[[MLXMPPManager sharedInstance] getConnectedAccountForID:[NSString stringWithFormat:@"%@",[self.contact objectForKey:@"account_id"]]];
  
    self.jid.stringValue =[self.contact objectForKey:@"buddy_name"];
    [self.table reloadData];
    

    self.resources = [[DataLayer sharedInstance] resourcesForContact:[self.contact objectForKey:@"buddy_name"]];
    [self.table reloadData];
}


#pragma mark  - tableview datasource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return self.resources.count;
}


#pragma  mark - tableview delegate
- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row;
{
    MLKeyRow *cell = [tableView makeViewWithIdentifier:@"KeyRow" owner:nil];
    cell.deviceid.stringValue = [[self.resources objectAtIndex:row] objectForKey:@"resource"];
    
    return cell;
}



-(void) toggleTrust
{
    
}

@end


