#include "ios_extras.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

using namespace godot;

void IosExtras::_bind_methods() {
	ClassDB::bind_method(D_METHOD("request_review"), &IosExtras::request_review);
	ClassDB::bind_method(D_METHOD("cloud_get", "key"), &IosExtras::cloud_get);
	ClassDB::bind_method(D_METHOD("cloud_set", "key", "value"), &IosExtras::cloud_set);
	ClassDB::bind_method(D_METHOD("cloud_sync"), &IosExtras::cloud_sync);
	// Otro aparato ha cambiado los datos de iCloud (llega en el hilo principal del juego).
	ADD_SIGNAL(MethodInfo("cloud_changed"));
}

IosExtras::IosExtras() {
	IosExtras *self = this;
	id token = [[NSNotificationCenter defaultCenter]
			addObserverForName:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
						object:[NSUbiquitousKeyValueStore defaultStore]
						 queue:[NSOperationQueue mainQueue]
					usingBlock:^(NSNotification *note) {
						self->call_deferred("emit_signal", "cloud_changed");
					}];
	observer = (__bridge_retained void *)token;
}

IosExtras::~IosExtras() {
	if (observer != nullptr) {
		id token = (__bridge_transfer id)observer;
		[[NSNotificationCenter defaultCenter] removeObserver:token];
		observer = nullptr;
	}
}

void IosExtras::request_review() {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIWindowScene *scene = nil;
		for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
			if ([candidate isKindOfClass:[UIWindowScene class]]) {
				scene = (UIWindowScene *)candidate;
				if (candidate.activationState == UISceneActivationStateForegroundActive) {
					break;
				}
			}
		}
		if (scene != nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			[SKStoreReviewController requestReviewInScene:scene];
#pragma clang diagnostic pop
		}
	});
}

String IosExtras::cloud_get(const String &key) const {
	NSString *ns_key = [NSString stringWithUTF8String:key.utf8().get_data()];
	NSString *value = [[NSUbiquitousKeyValueStore defaultStore] stringForKey:ns_key];
	if (value == nil) {
		return String();
	}
	return String::utf8([value UTF8String]);
}

void IosExtras::cloud_set(const String &key, const String &value) {
	NSString *ns_key = [NSString stringWithUTF8String:key.utf8().get_data()];
	NSString *ns_value = [NSString stringWithUTF8String:value.utf8().get_data()];
	NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
	[store setString:ns_value forKey:ns_key];
	[store synchronize];
}

bool IosExtras::cloud_sync() {
	return [[NSUbiquitousKeyValueStore defaultStore] synchronize];
}
