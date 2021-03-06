#import "ZYMessagingClient.h"

extern const char *__progname;
extern BOOL allowClosingReachabilityNatively;

#define IS_PROCESS(x) (strcmp(__progname, x) == 0)

@interface ZYMessagingClient () {
}

@property (nonatomic) BOOL allowedProcess;
@end

@implementation ZYMessagingClient
@synthesize allowedProcess;

+ (instancetype)sharedInstance {
	IF_SPRINGBOARD {
		@throw [NSException exceptionWithName:@"IsSpringBoardException" reason:@"Cannot use ZYMessagingClient in SpringBoard" userInfo:nil];
	}

	SHARED_INSTANCE2(ZYMessagingClient,
		[sharedInstance loadMessagingCenter];
		sharedInstance.hasRecievedData = NO;

		if ([NSBundle.mainBundle.executablePath hasPrefix:@"/Applications"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/var/stash/appsstash"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/var/containers/Bundle/Application"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/var/mobile/Applications"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/private/var/mobile/Applications"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/var/mobile/Containers/Bundle/Application"] ||
			[NSBundle.mainBundle.executablePath hasPrefix:@"/private/var/mobile/Containers/Bundle/Application"]) {
			HBLogDebug(@"[ReachApp] valid process for ZYMessagingClient");
			sharedInstance->allowedProcess = YES;
		}
	);
}

- (void)loadMessagingCenter {
	ZYMessageAppData data;

	data.shouldForceSize = NO;
	data.wantedClientOriginX = -1;
	data.wantedClientOriginY = -1;
	data.wantedClientWidth = -1;
	data.wantedClientHeight = -1;
	data.statusBarVisibility = YES;
	data.shouldForceStatusBar = NO;
	data.canHideStatusBarIfWanted = NO;
	data.forcedOrientation = UIInterfaceOrientationPortrait;
	data.shouldForceOrientation = NO;
	data.shouldUseExternalKeyboard = NO;
	data.forcePhoneMode = NO;
	data.isBeingHosted = NO;

	_currentData = data; // Initialize data

	serverCenter = [CPDistributedMessagingCenter centerNamed:@"com.shade.zypen.messaging.server"];
	rocketbootstrap_distributedmessagingcenter_apply(serverCenter);
}

- (void)alertUser:(NSString*)description {
		HBLogError(@"%@", description);
}

- (void)_requestUpdateFromServerWithTries:(NSInteger)tries {
	if (!allowedProcess) {
		return;
	}

	NSDictionary *dict = @{ @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier };
	NSDictionary *data = [serverCenter sendMessageAndReceiveReplyName:ZYMessagingUpdateAppInfoMessageName userInfo:dict];
	if (data && [data objectForKey:@"data"] != nil) {
		ZYMessageAppData actualData;
		[data[@"data"] getBytes:&actualData length:sizeof(actualData)];
		[self updateWithData:actualData];
		self.hasRecievedData = YES;
	} else {
		if (tries <= 4) {
			[self _requestUpdateFromServerWithTries:tries + 1];
		} else {
			[self alertUser:[NSString stringWithFormat:@"App \"%@\" is unable to communicate with messaging server", [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"] ?: NSBundle.mainBundle.bundleIdentifier]];
		}
	}
}

- (void)requestUpdateFromServer {
	[self _requestUpdateFromServerWithTries:0];
}

- (void)updateWithData:(ZYMessageAppData)data {
	BOOL didStatusBarVisibilityChange = _currentData.shouldForceStatusBar != data.shouldForceStatusBar;
	BOOL didOrientationChange = _currentData.shouldForceOrientation != data.shouldForceOrientation;
	BOOL didSizingChange  =_currentData.shouldForceSize != data.shouldForceSize;

	/* THE REAL IMPORTANT BIT */
	_currentData = data;

	if (didStatusBarVisibilityChange && !data.shouldForceStatusBar){
		[UIApplication.sharedApplication ZY_forceStatusBarVisibility:_currentData.statusBarVisibility orRevert:YES];
	} else if (data.shouldForceStatusBar) {
		[UIApplication.sharedApplication ZY_forceStatusBarVisibility:_currentData.statusBarVisibility orRevert:NO];
	}

	if (didSizingChange && !data.shouldForceSize) {
		[UIApplication.sharedApplication ZY_updateWindowsForSizeChange:CGSizeMake(data.wantedClientWidth, data.wantedClientHeight) isReverting:YES];
	} else if (data.shouldForceSize) {
		[UIApplication.sharedApplication ZY_updateWindowsForSizeChange:CGSizeMake(data.wantedClientWidth, data.wantedClientHeight) isReverting:NO];
	}

	if (didOrientationChange && !data.shouldForceOrientation) {
		[UIApplication.sharedApplication ZY_forceRotationToInterfaceOrientation:data.forcedOrientation isReverting:YES];
	} else if (data.shouldForceOrientation) {
		[UIApplication.sharedApplication ZY_forceRotationToInterfaceOrientation:data.forcedOrientation isReverting:NO];
	}
	allowClosingReachabilityNatively = YES;
}

- (void)notifyServerWithKeyboardContextId:(NSUInteger)cid {
	NSDictionary *dict = @{ @"contextId": @(cid), @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier };
	[serverCenter sendMessageName:ZYMessagingUpdateKeyboardContextIdMessageName userInfo:dict];
}

- (void)notifyServerToShowKeyboard {
	NSDictionary *dict = @{ @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier };
	[serverCenter sendMessageName:ZYMessagingShowKeyboardMessageName userInfo:dict];
}

- (void)notifyServerToHideKeyboard {
	[serverCenter sendMessageName:ZYMessagingHideKeyboardMessageName userInfo:nil];
}

- (void)notifyServerOfKeyboardSizeUpdate:(CGSize)size {
	NSDictionary *dict = @{ @"size": NSStringFromCGSize(size) };
	[serverCenter sendMessageName:ZYMessagingUpdateKeyboardSizeMessageName userInfo:dict];
}

- (BOOL)notifyServerToOpenURL:(NSURL*)url openInWindow:(BOOL)openWindow {
	NSDictionary *dict = @{
		@"url": url.absoluteString,
		@"openInWindow": @(openWindow)
	};
	return [[serverCenter sendMessageAndReceiveReplyName:ZYMessagingOpenURLKMessageName userInfo:dict][@"success"] boolValue];
}

- (void)notifySpringBoardOfFrontAppChangeToSelf {
	NSString *ident = NSBundle.mainBundle.bundleIdentifier;
	if (!ident) {
		return;
	}
	if ([self isBeingHosted] && (!self.knownFrontmostApp || ![self.knownFrontmostApp isEqual:ident])) {
		[serverCenter sendMessageName:ZYMessagingChangeFrontMostAppMessageName userInfo:@{ @"bundleIdentifier": ident }];
	}
}

- (BOOL)shouldUseExternalKeyboard {
	return _currentData.shouldUseExternalKeyboard;
}

- (BOOL)shouldResize {
	return _currentData.shouldForceSize;
}

- (CGSize)resizeSize {
	return CGSizeMake(_currentData.wantedClientWidth, _currentData.wantedClientHeight);
}

- (BOOL)shouldHideStatusBar {
	return _currentData.shouldForceStatusBar && _currentData.statusBarVisibility == NO;
}

- (BOOL)shouldShowStatusBar {
	return _currentData.shouldForceStatusBar && _currentData.statusBarVisibility == YES;
}

- (UIInterfaceOrientation)forcedOrientation {
	return _currentData.forcedOrientation;
}

- (BOOL)shouldForceOrientation {
	return _currentData.shouldForceOrientation;
}

- (BOOL)isBeingHosted {
	return _currentData.isBeingHosted;
}

@end

void reloadClientData(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
	[ZYMessagingClient.sharedInstance requestUpdateFromServer];
}

void updateFrontmostApp(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
	ZYMessagingClient.sharedInstance.knownFrontmostApp = ((__bridge NSDictionary*)userInfo)[@"bundleIdentifier"];
}

%ctor {
	IF_SPRINGBOARD {

	} else {
		[ZYMessagingClient sharedInstance];
    	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &reloadClientData, (__bridge CFStringRef)[NSString stringWithFormat:@"com.shade.zypen.clientupdate-%@",NSBundle.mainBundle.bundleIdentifier], NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    	CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), NULL, &updateFrontmostApp, CFSTR("com.shade.zypen.frontmostAppDidUpdate"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	}
}
