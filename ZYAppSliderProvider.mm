#import "ZYAppSliderProvider.h"
#import "ZYHostedAppView.h"

@interface ZYAppSliderProvider () {
	NSMutableDictionary *cachedViews;
}
@end

@implementation ZYAppSliderProvider
@synthesize currentIndex, availableIdentifiers;

- (id)init {
	if (self = [super init]) {
		cachedViews = [NSMutableDictionary dictionary];
	}
	return self;
}

- (BOOL)canGoLeft {
	return currentIndex - 1 >= 0 && availableIdentifiers.count > 0;
}

- (BOOL)canGoRight {
	return availableIdentifiers.count > currentIndex + 1;
}

- (ZYHostedAppView*)viewToTheLeft {
	if (self.canGoLeft) {
		NSString *ident = [availableIdentifiers objectAtIndex:currentIndex - 1];

		if (!ident) {
			return nil;
		}
		if ([cachedViews objectForKey:ident]) {
			return cachedViews[ident];
		}
		ZYHostedAppView *view = [[ZYHostedAppView alloc] initWithBundleIdentifier:ident];
		[view preloadApp];
		cachedViews[ident] = view;
		return view;
	}
	return nil;
}

- (ZYHostedAppView*)viewToTheRight {
	if (self.canGoRight) {
		NSString *ident = [availableIdentifiers objectAtIndex:currentIndex + 1];

		if (!ident) {
			return nil;
		}
		if ([cachedViews objectForKey:ident]) {
			return cachedViews[ident];
		}
		ZYHostedAppView *view = [[ZYHostedAppView alloc] initWithBundleIdentifier:ident];
		[view preloadApp];
		cachedViews[ident] = view;
		return view;
	}
	return nil;
}

- (ZYHostedAppView*)viewAtCurrentIndex {
	NSString *ident = [availableIdentifiers objectAtIndex:currentIndex];

	if (!ident) {
		return nil;
	}
	if ([cachedViews objectForKey:ident]) {
		return cachedViews[ident];
	}
	ZYHostedAppView *view = [[ZYHostedAppView alloc] initWithBundleIdentifier:ident];
	[view preloadApp];
	cachedViews[ident] = view;
	return view;
}

- (void)goToTheLeft {
	if (self.canGoLeft)
		currentIndex--;
}

- (void)goToTheRight {
	if (self.canGoRight)
		currentIndex++;
}
@end
