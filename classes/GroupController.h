//
//  GroupController.h
//  GeektoolPreferencePane
//
//  Created by Kevin Nygaard on 3/17/09.
//  Copyright 2009 AllocInit. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NTGroup;

@interface GroupController : NSArrayController
{
    IBOutlet id logController;
    
    // used with drag and drop
    NSString *MovedRowsType;
    NSString *CopiedRowsType;
    IBOutlet id tableView;

    // used for observing
    NTGroup *selectedGroup;
    
    // UI
    IBOutlet id groupsSheet;
}
- (void)awakeFromNib;
- (void)dealloc;
// Observing
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
// UI
- (IBAction)showGroupsCustomization:(id)sender;
- (IBAction)groupsSheetClose:(id)sender;
// Content Remove/Dupe
- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes;
- (IBAction)duplicate:(id)sender;
// Drag n' Drop Stuff
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;
- (NSIndexSet *)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)fromIndexSet toIndex:(unsigned int)insertIndex;
@end
