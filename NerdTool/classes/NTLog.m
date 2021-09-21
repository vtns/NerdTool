//
//  NTLog.m
//  NerdTool
//
//  Created by Kevin Nygaard on 7/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NTLog.h"
#import "LogWindow.h"
#import "LogTextField.h"
#import "NTGroup.h"
#import "ANSIEscapeHelper.h"

#import "defines.h"
#import "NSDictionary+IntAndBoolAccessors.h"
#import "NS(Attributed)String+Geometrics.h"

@implementation NTLog

@synthesize properties=properties;
@synthesize active=active;
@synthesize parentGroup=parentGroup;

@synthesize windowController=windowController;
@synthesize window=window;

@synthesize prefsView=prefsView;

@synthesize highlightSender=highlightSender;
@synthesize postActivationRequest=postActivationRequest;
@synthesize _isBeingDragged=_isBeingDragged;

@synthesize arguments=arguments;
@synthesize env=env;
@synthesize timer=timer;
@synthesize task=task;

@synthesize lastRecievedString=lastRecievedString;

#pragma mark Properties
// Subclasses would probably want to override the following methods
- (NSString *)logTypeName
{
    return @"Box";
}

- (BOOL)needsDisplayUIBox
{
    return YES;
}

- (NSString *)preferenceNibName
{
    return @"";
}

- (NSString *)displayNibName
{
    return @"";
}

- (NSDictionary *)defaultProperties
{
    return [NSDictionary dictionary];
}

- (void)setupInterfaceBindingsWithObject:(id)bindee
{
    return;
}

- (void)destroyInterfaceBindings
{
    return;
}

#pragma mark Window Management
- (void)updateWindowIncludingTimer:(BOOL)updateTimer
{
    NSRect newRect = [self screenToRect:[self rect]];
    if ([properties boolForKey:@"sizeToScreen"]) newRect = [[[NSScreen screens]objectAtIndex:0]frame];
    
    [window setFrame:newRect display:NO];
    
    NSRect tmpRect = [self rect];
    tmpRect.origin = NSZeroPoint;
    
    [window setHasShadow:[[self properties]boolForKey:@"shadowWindow"]];
    [window setLevel:[[self properties]integerForKey:@"alwaysOnTop"]?kCGMaximumWindowLevel:kCGDesktopIconWindowLevel];
    [window setSticky:![[self properties]boolForKey:@"alwaysOnTop"]];
    
    if ([self needsDisplayUIBox])
    {
        [window setTextRect:tmpRect]; 
        [window setTextBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"backgroundColor"]]];
        [[window textView]updateTextAttributesUsingProps:properties];
        
        if (![properties boolForKey:@"useAsciiEscapes"] || !lastRecievedString) [[window textView]applyAttributes:[[window textView]attributes]];
        else [[window textView]processAndSetText:lastRecievedString withEscapes:YES andCustomColors:[self customAnsiColors] insert:NO];
    }
    
    if (![window isVisible])
    {
        [self front];
        [parentGroup reorder];
    }
    postActivationRequest = YES;
    
    if (updateTimer) [self updateTimer];
    
    [window display];
}

#pragma mark -
#pragma mark Log Container
#pragma mark -

- (id)initWithProperties:(NSDictionary*)newProperties
{
	if (!(self = [super init])) return nil;
    
    [self setProperties:[NSMutableDictionary dictionaryWithDictionary:newProperties]];
    [self setActive:[NSNumber numberWithBool:NO]];
    
    _loadedView = NO;
    windowController = nil;
    highlightSender = nil;
    lastRecievedString = nil;
    _visibleFrame = [[[NSScreen screens]objectAtIndex:0]frame];
    
    [self setupPreferenceObservers];
    return self;
}

- (id)init
{    
    return [self initWithProperties:[self defaultProperties]];
}    

- (void)dealloc
{
    [self removePreferenceObservers];
    [self destroyLogProcess];
    [properties release];
    [active release];
    [super dealloc];
}

#pragma mark Interface
- (NSView *)loadPrefsViewAndBind:(id)bindee
{
    if (_loadedView) return nil;
    if (!prefsView) [NSBundle loadNibNamed:[self preferenceNibName] owner:self];
    
    [self setupInterfaceBindingsWithObject:bindee];
    
    _loadedView = YES;
    return prefsView;
}

- (NSView *)unloadPrefsViewAndUnbind
{
    if (!_loadedView) return nil;
    
    [self destroyInterfaceBindings];
    
    _loadedView = NO;
    return prefsView;
}

- (void)setupPreferenceObservers
{
    [self addObserver:self forKeyPath:@"active" options:0 context:NULL];
    
    [self addObserver:self forKeyPath:@"properties.name" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.enabled" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.group" options:0 context:NULL];
    
    [self addObserver:self forKeyPath:@"properties.x" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.y" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.w" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.h" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.alwaysOnTop" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.sizeToScreen" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.shadowWindow" options:0 context:NULL];
    
    if (![self needsDisplayUIBox]) return;
    [self addObserver:self forKeyPath:@"properties.font" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.stringEncoding" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.textColor" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.backgroundColor" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.shadowColor" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.wrap" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.alignment" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.shadowText" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.useAsciiEscapes" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBlack" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgRed" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgGreen" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgYellow" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBlue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgMagenta" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgCyan" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgWhite" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBlack" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgRed" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgGreen" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgYellow" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBlue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgMagenta" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgCyan" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgWhite" options:0 context:NULL];    
    [self addObserver:self forKeyPath:@"properties.fgBrightBlack" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightRed" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightGreen" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightYellow" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightBlue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightMagenta" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightCyan" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.fgBrightWhite" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightBlack" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightRed" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightGreen" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightYellow" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightBlue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightMagenta" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightCyan" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.bgBrightWhite" options:0 context:NULL];    
}

- (void)removePreferenceObservers
{
    [self removeObserver:self forKeyPath:@"active"];
    
    [self removeObserver:self forKeyPath:@"properties.name"];
    [self removeObserver:self forKeyPath:@"properties.enabled"];
    [self removeObserver:self forKeyPath:@"properties.group"];
    
    [self removeObserver:self forKeyPath:@"properties.x"];
    [self removeObserver:self forKeyPath:@"properties.y"];
    [self removeObserver:self forKeyPath:@"properties.w"];
    [self removeObserver:self forKeyPath:@"properties.h"];
    [self removeObserver:self forKeyPath:@"properties.alwaysOnTop"];
    [self removeObserver:self forKeyPath:@"properties.sizeToScreen"];
    [self removeObserver:self forKeyPath:@"properties.shadowWindow"];
    
    if (![self needsDisplayUIBox]) return;
    [self removeObserver:self forKeyPath:@"properties.font"];
    [self removeObserver:self forKeyPath:@"properties.stringEncoding"];
    [self removeObserver:self forKeyPath:@"properties.textColor"];
    [self removeObserver:self forKeyPath:@"properties.backgroundColor"];
    [self removeObserver:self forKeyPath:@"properties.shadowColor"];
    [self removeObserver:self forKeyPath:@"properties.wrap"];
    [self removeObserver:self forKeyPath:@"properties.alignment"];
    [self removeObserver:self forKeyPath:@"properties.shadowText"];
    [self removeObserver:self forKeyPath:@"properties.useAsciiEscapes"];
    [self removeObserver:self forKeyPath:@"properties.fgBlack"];
    [self removeObserver:self forKeyPath:@"properties.fgRed"];
    [self removeObserver:self forKeyPath:@"properties.fgGreen"];
    [self removeObserver:self forKeyPath:@"properties.fgYellow"];
    [self removeObserver:self forKeyPath:@"properties.fgBlue"];
    [self removeObserver:self forKeyPath:@"properties.fgMagenta"];
    [self removeObserver:self forKeyPath:@"properties.fgCyan"];
    [self removeObserver:self forKeyPath:@"properties.fgWhite"];
    [self removeObserver:self forKeyPath:@"properties.bgBlack"];
    [self removeObserver:self forKeyPath:@"properties.bgRed"];
    [self removeObserver:self forKeyPath:@"properties.bgGreen"];
    [self removeObserver:self forKeyPath:@"properties.bgYellow"];
    [self removeObserver:self forKeyPath:@"properties.bgBlue"];
    [self removeObserver:self forKeyPath:@"properties.bgMagenta"];
    [self removeObserver:self forKeyPath:@"properties.bgCyan"];
    [self removeObserver:self forKeyPath:@"properties.bgWhite"];    
    [self removeObserver:self forKeyPath:@"properties.fgBrightBlack"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightRed"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightGreen"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightYellow"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightBlue"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightMagenta"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightCyan"];
    [self removeObserver:self forKeyPath:@"properties.fgBrightWhite"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightBlack"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightRed"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightGreen"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightYellow"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightBlue"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightMagenta"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightCyan"];
    [self removeObserver:self forKeyPath:@"properties.bgBrightWhite"];    
}

#pragma mark KVC
- (void)set_isBeingDragged:(BOOL)var
{
    static BOOL needCoordObservers = NO;
    _isBeingDragged = var;
    if (_isBeingDragged && !needCoordObservers)
    {
        [self removeObserver:self forKeyPath:@"properties.x"];
        [self removeObserver:self forKeyPath:@"properties.y"];
        [self removeObserver:self forKeyPath:@"properties.w"];
        [self removeObserver:self forKeyPath:@"properties.h"];
        needCoordObservers = YES;
    }
    else if (needCoordObservers)
    {
        [self addObserver:self forKeyPath:@"properties.x" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        [self addObserver:self forKeyPath:@"properties.y" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        [self addObserver:self forKeyPath:@"properties.w" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        [self addObserver:self forKeyPath:@"properties.h" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
        needCoordObservers = NO;
    }
}

- (BOOL)_isBeingDragged
{
    return _isBeingDragged;
}

#pragma mark -
#pragma mark Log Process
#pragma mark -
#pragma mark Management
- (void)createLogProcess
{   
    NSWindowController *winCtrl = [[NSWindowController alloc]initWithWindowNibName:[self displayNibName]];
    [self setWindowController:winCtrl];
    [self setWindow:(LogWindow *)[windowController window]];
    [window setParentLog:self];
    
    // append app support folder to shell PATH
    NSMutableDictionary *tmpEnv = [[NSMutableDictionary alloc]initWithDictionary:[[NSProcessInfo processInfo]environment]];
    NSString *appendedPath = [NSString stringWithFormat:@"%@:%@",[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) objectAtIndex:0]stringByAppendingPathComponent:[[NSProcessInfo processInfo]processName]],[tmpEnv objectForKey:@"PATH"]];
    [tmpEnv setObject:appendedPath forKey:@"PATH"]; 
    [tmpEnv setObject:@"xterm-color" forKey:@"TERM"];
    [self setEnv:tmpEnv];
    
    [self setupProcessObservers];
    
    [winCtrl release];
    [tmpEnv release];
}

- (void)destroyLogProcess
{
    // removes process observers (they call notificationHandler:)
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [windowController close];
    [self setWindowController:nil];
    [self setEnv:nil];
    
    [self setArguments:nil];
    [self setTask:nil];
    [self setTimer:nil];
}

#pragma mark Observing
- (void)setupProcessObservers
{
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(notificationHandler:) name:@"NSLogViewMouseDown" object:window];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(notificationHandler:) name:NSWindowDidResizeNotification object:window];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(notificationHandler:) name:NSWindowDidMoveNotification object:window];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(notificationHandler:) name:@"NSLogViewMouseUp" object:window];
}

- (void)notificationHandler:(NSNotification *)notification
{    
    // when the resolution changes, don't change the window positions
    if (!NSEqualRects(_visibleFrame,[[[NSScreen screens]objectAtIndex:0]frame]))
    {
        _visibleFrame = [[[NSScreen screens]objectAtIndex:0]frame];
    }
    else if (([[notification name]isEqualToString:NSWindowDidResizeNotification] || [[notification name]isEqualToString:NSWindowDidMoveNotification]))
    {                
        NSRect newCoords = [self screenToRect:[[notification object]frame]];
        [properties setValue:[NSNumber numberWithInt:NSMinX(newCoords)] forKey:@"x"];
        [properties setValue:[NSNumber numberWithInt:NSMinY(newCoords)] forKey:@"y"];
        [properties setValue:[NSNumber numberWithInt:NSWidth(newCoords)] forKey:@"w"];
        [properties setValue:[NSNumber numberWithInt:NSHeight(newCoords)] forKey:@"h"];
    }
    else if ([[notification name]isEqualToString:@"NSLogViewMouseDown"])
        [self set_isBeingDragged:YES];
    else if ([[notification name]isEqualToString:@"NSLogViewMouseUp"])
        [self set_isBeingDragged:NO];
}

#pragma mark KVC
- (void)setTask:(NSTask*)newTask
{
    [task autorelease];
    if ([task isRunning]) [task terminate];
    task = [newTask retain];
}

- (NSTask*)task
{
    return [[task retain] autorelease];
}

- (void)setTimer:(NSTimer*)newTimer
{
    [timer autorelease];
    if ([timer isValid])
    {
        [self retain]; // to counter our balancing done in updateTimer
        [timer invalidate];
    }
    timer = [newTimer retain];
}

- (NSTimer*)timer
{
    return [[timer retain] autorelease];
}


- (void)killTimer
{
    if (!timer) return;
    [self setTimer:nil];
}

- (void)updateTimer
{
    int refreshTime = [[self properties]integerForKey:@"refresh"];
    BOOL timerRepeats = refreshTime?YES:NO;
    
    [self setTimer:[NSTimer scheduledTimerWithTimeInterval:refreshTime target:self selector:@selector(timerFired:) userInfo:nil repeats:timerRepeats]];
    [timer fire];
    
    if (timerRepeats) [self release]; // since timer repeats, self is retained. we don't want this
    else [self setTimer:nil];
}

- (void)timerFired:(NSTimer*)timer
{
    [self performSelector:@selector(updateCommand:) withObject:timer];
    int refreshTime = [timer timeInterval];
    if (refreshTime && (3600 % refreshTime) == 0)
    {
        // when refreshTime is divisor of an hour, adjust the fire time to exact multiple of refreshTime
        NSTimeInterval nextTime = [[NSDate now] timeIntervalSinceReferenceDate];
        nextTime = floor(nextTime / refreshTime) * refreshTime;
        while (nextTime <= [[NSDate now] timeIntervalSinceReferenceDate])
        {
            nextTime += refreshTime;
        }
        [timer setFireDate:[NSDate dateWithTimeIntervalSinceReferenceDate:nextTime]];
    }
}

#pragma mark Window Management
- (void)setHighlighted:(BOOL)val from:(id)sender
{
    highlightSender = sender;
	
    if (windowController) [[self window]setHighlighted:val];
    else postActivationRequest = YES;
}

- (void)front
{
    [window orderFront:self];
}

- (IBAction)attemptBestWindowSize:(id)sender
{
    NSSize bestFit = [[[window textView]attributedString] sizeForWidth:[properties boolForKey:@"wrap"]?NSWidth([window frame]):FLT_MAX height:FLT_MAX];
    [window setContentSize:bestFit];
    [[NSNotificationCenter defaultCenter]postNotificationName:NSWindowDidResizeNotification object:window];
    [window displayIfNeeded];
}

#pragma mark  
#pragma mark Convience
- (NSDictionary*)customAnsiColors
{
    NSDictionary *colors = [[NSDictionary alloc]initWithObjectsAndKeys:
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBlack"]],[NSNumber numberWithInt:SGRCodeFgBlack],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgRed"]],[NSNumber numberWithInt:SGRCodeFgRed],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgGreen"]],[NSNumber numberWithInt:SGRCodeFgGreen],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgYellow"]],[NSNumber numberWithInt:SGRCodeFgYellow],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBlue"]],[NSNumber numberWithInt:SGRCodeFgBlue],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgMagenta"]],[NSNumber numberWithInt:SGRCodeFgMagenta],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgCyan"]],[NSNumber numberWithInt:SGRCodeFgCyan],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgWhite"]],[NSNumber numberWithInt:SGRCodeFgWhite],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBlack"]],[NSNumber numberWithInt:SGRCodeBgBlack],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgRed"]],[NSNumber numberWithInt:SGRCodeBgRed],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgGreen"]],[NSNumber numberWithInt:SGRCodeBgGreen],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgYellow"]],[NSNumber numberWithInt:SGRCodeBgYellow],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBlue"]],[NSNumber numberWithInt:SGRCodeBgBlue],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgMagenta"]],[NSNumber numberWithInt:SGRCodeBgMagenta],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgCyan"]],[NSNumber numberWithInt:SGRCodeBgCyan],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgWhite"]],[NSNumber numberWithInt:SGRCodeBgWhite],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightBlack"]],[NSNumber numberWithInt:SGRCodeFgBrightBlack],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightRed"]],[NSNumber numberWithInt:SGRCodeFgBrightRed],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightGreen"]],[NSNumber numberWithInt:SGRCodeFgBrightGreen],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightYellow"]],[NSNumber numberWithInt:SGRCodeFgBrightYellow],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightBlue"]],[NSNumber numberWithInt:SGRCodeFgBrightBlue],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightMagenta"]],[NSNumber numberWithInt:SGRCodeFgBrightMagenta],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightCyan"]],[NSNumber numberWithInt:SGRCodeFgBrightCyan],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"fgBrightWhite"]],[NSNumber numberWithInt:SGRCodeFgBrightWhite],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightBlack"]],[NSNumber numberWithInt:SGRCodeBgBrightBlack],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightRed"]],[NSNumber numberWithInt:SGRCodeBgBrightRed],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightGreen"]],[NSNumber numberWithInt:SGRCodeBgBrightGreen],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightYellow"]],[NSNumber numberWithInt:SGRCodeBgBrightYellow],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightBlue"]],[NSNumber numberWithInt:SGRCodeBgBrightBlue],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightMagenta"]],[NSNumber numberWithInt:SGRCodeBgBrightMagenta],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightCyan"]],[NSNumber numberWithInt:SGRCodeBgBrightCyan],
                            [NSUnarchiver unarchiveObjectWithData:[properties objectForKey:@"bgBrightWhite"]],[NSNumber numberWithInt:SGRCodeBgBrightWhite],
                            nil];
    return [colors autorelease];
    
}

- (NSRect)screenToRect:(NSRect)appleCoordRect
{
    // remember, the coordinates we use are with respect to the top left corner (both window and screen), but the actual OS takes them with respect to the bottom left (both window and screen), so we must convert between these
    NSRect screenSize = [[[NSScreen screens]objectAtIndex:0]frame];
    return NSMakeRect(appleCoordRect.origin.x,(screenSize.size.height - appleCoordRect.origin.y - appleCoordRect.size.height),appleCoordRect.size.width,appleCoordRect.size.height);
}

- (NSRect)rect
{
    return NSMakeRect([properties integerForKey:@"x"],
                      [properties integerForKey:@"y"],
                      [properties integerForKey:@"w"],
                      [properties integerForKey:@"h"]);
}

- (BOOL)equals:(NTLog*)comp
{
    if ([[self properties]isEqualTo:[comp properties]]) return YES;
    else return NO;
}

- (NSString*)description
{
    return [NSString stringWithFormat: @"Log (%@):[%@]%@",[self logTypeName],[[[self properties]objectForKey:@"enabled"]boolValue]?@"X":@" ",[[self properties]objectForKey:@"name"]];
}

#pragma mark Copying
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class]allocWithZone:zone]initWithProperties:[self properties]];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

#pragma mark Coding
- (id)initWithCoder:(NSCoder *)coder
{
    // allows object to change properties and still function properly. Old, unused properties are NOT deleted.
    id tmpObject = [self init];
    NSMutableDictionary *loadedProps = [coder decodeObjectForKey:@"properties"];
    [properties addEntriesFromDictionary:loadedProps];
    
    return tmpObject;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:properties forKey:@"properties"];
}
@end
