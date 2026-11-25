#import <Foundation/Foundation.h>

/* BlitzMax's appstub creates NSApp before SDL, bypassing SDL's registration
   of ApplePressAndHoldEnabled. Use the process-only argument domain so this
   game setting also takes precedence over inherited user defaults. */
int dive_disable_press_and_hold(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *arguments = [[defaults volatileDomainForName:NSArgumentDomain] mutableCopy];
        if (!arguments) arguments = [[NSMutableDictionary alloc] init];
        [arguments setObject:@NO forKey:@"ApplePressAndHoldEnabled"];
        [defaults setVolatileDomain:arguments forName:NSArgumentDomain];
        [arguments release];
        return ![defaults boolForKey:@"ApplePressAndHoldEnabled"];
    }
}
